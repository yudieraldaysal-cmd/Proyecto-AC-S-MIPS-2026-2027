#!/usr/bin/env python3
"""Ejecuta programas en la CPU de circuit/smips.circ y compara la salida del TTY con la de MARS.

Uso: python3 tools/run_tests.py [--circuito archivo.circ] [--con-ventana] [fuente.asm ...]
Sin fuentes prueba programs/*.asm y tests/*.asm. Compila tools/Run.java y lo ejecuta;
no usa el modo fuente de Java (que falla en los JRE actuales). Necesita un JDK (javac),
MARS (MARS_JAR), Logisim Evolution 5.0.0 (LOGISIM_JAR) y, solo con entidades VHDL,
Questa con licencia (QUESTA_BIN, SALT_LICENSE_SERVER).

Por defecto se ejecuta sin ventana (headless), que es lo que funciona sin pantalla y en
scripts. Si la CPU usa VHDL, Questa necesita la ventana de Logisim: usa --con-ventana
(o SMIPS_HEADLESS=0) en una sesion grafica.

Variables de entorno utiles:
  JAVA, JAVAC, JDK_BIN, JAVA_HOME  localizar el JDK
  LOGISIM_JAR                      ruta al .jar de Logisim 5.0.0
  MARS_JAR                         ruta al .jar de MARS
  SMIPS_HEADLESS=0|1               forzar/no forzar modo sin ventana
"""
from pathlib import Path
import argparse
import os
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parent.parent
HERE = ROOT/'tools'
CICLOS_MAX = 60000  # con 4-5 ciclos por instruccion, el programa mas largo usa unos 8000


def buscar_logisim():
    candidatos = []
    if os.environ.get('LOGISIM_JAR'):
        candidatos.append(Path(os.environ['LOGISIM_JAR']))
    candidatos += [
        Path.home()/'Downloads/logisim-evolution-5.0.0-all.jar',
        Path('/snap/logisim-evolution-snapcraft/current/jar/logisim-evolution.jar'),
        ROOT.parent.parent/'logisim-evolution-5.0.0-all.jar',
    ]
    for candidato in candidatos:
        if candidato.is_file():
            return candidato
    sys.exit('No encuentro el JAR de Logisim 5.0.0. Define LOGISIM_JAR.')


def buscar_jdk():
    """Devuelve la carpeta bin de un JDK con java y javac."""
    candidatos = []
    if os.environ.get('JDK_BIN'):
        candidatos.append(Path(os.environ['JDK_BIN']))
    if os.environ.get('JAVA_HOME'):
        candidatos.append(Path(os.environ['JAVA_HOME'])/'bin')
    candidatos += [
        Path.home()/'.local/share/ElyPrismLauncher/java/java-runtime-epsilon/bin',
        Path('/usr/lib/jvm/java-21-openjdk/bin'),
        Path('/usr/lib/jvm/java-17-openjdk/bin'),
    ]
    javac = shutil.which('javac')
    if javac:
        candidatos.append(Path(javac).parent)
    for candidato in candidatos:
        if (candidato/'java').is_file() and (candidato/'javac').is_file():
            return candidato
    sys.exit('No encuentro un JDK con javac. Define JDK_BIN o JAVA_HOME.')


def normalizar(texto):
    lineas = [linea.rstrip() for linea in texto.split('\n')]
    while lineas and not lineas[-1]:
        lineas.pop()
    return '\n'.join(lineas)


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument('--circuito', type=Path, default=ROOT/'circuit/smips.circ')
    parser.add_argument('--con-ventana', action='store_true',
                        help='crear la ventana de Logisim (necesario con VHDL/Questa)')
    parser.add_argument('fuentes', type=Path, nargs='*')
    args = parser.parse_args()

    if args.fuentes:
        fuentes = args.fuentes
    else:
        fuentes = sorted((ROOT/'programs').glob('*.asm')) + sorted((ROOT/'tests').glob('*.asm'))
    if not fuentes:
        sys.exit('No hay programas .asm que probar.')
    for fuente in fuentes:
        if not fuente.is_file():
            sys.exit(f'No existe {fuente}')

    jar = buscar_logisim()
    jdk = buscar_jdk()
    java, javac = str(jdk/'java'), str(jdk/'javac')
    mars = Path(os.environ.get('MARS_JAR', str(Path.home()/'Apps/mars/Mars4_5.jar')))
    if not mars.is_file():
        sys.exit(f'No encuentro MARS en {mars}. Define MARS_JAR.')

    headless_env = os.environ.get('SMIPS_HEADLESS')
    if args.con_ventana:
        headless = False
    elif headless_env is not None and headless_env.strip() != '':
        headless = headless_env.strip().lower() not in ('0', 'false', 'no')
    else:
        headless = True  # sin VHDL la ventana no hace falta; con VHDL usa --con-ventana

    print(f'Logisim: {jar}')
    print(f'JDK:     {jdk}')
    print(f'MARS:    {mars}')
    print(f'Modo:    {"sin ventana (headless)" if headless else "con ventana"}')

    with tempfile.TemporaryDirectory(prefix='smips-probar-') as directorio:
        directorio = Path(directorio)
        clases = directorio/'classes'
        clases.mkdir()
        compilacion = subprocess.run([javac, '-cp', str(jar), '-d', str(clases), str(HERE/'Run.java')],
                                     capture_output=True, text=True)
        if compilacion.returncode:
            sys.exit(f'No se pudo compilar tools/Run.java:\n{compilacion.stderr[-4000:]}')

        imagenes, esperado, avisos = {}, {}, {}
        entorno = dict(os.environ, JAVA=java, MARS_JAR=str(mars))
        for fuente in fuentes:
            imagen = directorio/(fuente.stem + '.hex')
            ensamblado = subprocess.run([sys.executable, str(HERE/'assemble.py'), str(fuente), '-o', str(imagen)],
                                        capture_output=True, text=True, env=entorno)
            if ensamblado.returncode:
                sys.exit(f'No se pudo ensamblar {fuente}:\n{ensamblado.stdout[-4000:]}{ensamblado.stderr[-4000:]}')
            avisos[fuente] = [linea for linea in ensamblado.stdout.splitlines() if linea.startswith('Aviso')]
            mars_proc = subprocess.run([java, '-Djava.awt.headless=true', '-jar', str(mars), 'nc', 'mc',
                                        'CompactTextAtZero', str(fuente)],
                                       capture_output=True, text=True)
            if mars_proc.returncode:
                sys.exit(f'MARS no pudo ejecutar {fuente}:\n{mars_proc.stdout[-4000:]}{mars_proc.stderr[-4000:]}')
            imagenes[str(imagen)] = fuente
            esperado[fuente] = normalizar(mars_proc.stdout)

        print(f'Ejecutando {len(fuentes)} programas en la placa...', flush=True)
        orden = [java, f'-Djava.util.prefs.userRoot={directorio}/prefs']
        if headless:
            orden.append('-Djava.awt.headless=true')
        orden += ['-cp', f'{jar}{os.pathsep}{clases}', 'Run',
                  str(args.circuito.resolve()), str(CICLOS_MAX), '0', *imagenes]
        # Cada programa se informa en cuanto termina.
        proceso = subprocess.Popen(orden, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        resultados, fallos = [], 0
        for linea in proceso.stdout:
            if not linea.startswith('RESULTADO'):
                continue
            _, imagen, detenido, ciclos, pc, tty = linea.rstrip('\n').split('\t')
            resultados.append(imagen)
            fuente = imagenes[imagen]
            salida = normalizar(bytes.fromhex(tty).decode())
            ok = detenido == 'true' and salida == esperado[fuente]
            fallos += not ok
            print(f'{"OK   " if ok else "FALLO"} {os.path.relpath(fuente)}  ({ciclos} ciclos)', flush=True)
            for aviso in avisos[fuente]:
                print(f'  {aviso}', flush=True)
            if not ok:
                print(f'  detenido={detenido} (MEM_ADDR final 0x{pc})\n  esperado (MARS):\n    ' +
                      esperado[fuente].replace('\n', '\n    ') +
                      '\n  obtenido (TTY):\n    ' + salida.replace('\n', '\n    '), flush=True)
        error = proceso.stderr.read()
        if proceso.wait() or len(resultados) != len(fuentes):
            if 'HeadlessException' in error or 'AWTError' in error or 'X11' in error:
                print('Pista: la ejecucion necesita una pantalla (VHDL/Questa). '
                      'Ejecuta con --con-ventana en una sesion grafica.', file=sys.stderr)
            sys.exit(f'Fallo la ejecucion:\n{error[-4000:]}')
    print(f'\n{len(resultados) - fallos}/{len(resultados)} correctos')
    sys.exit(1 if fallos else 0)


if __name__ == '__main__':
    main()
