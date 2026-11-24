# Progreso — CPU multiciclo S-MIPS (Logisim Evolution 5.0.0)

**Última actualización:** 2026-11-24 13:45 (America/Havana)
**Estado:** CPU **funcional y verificada**. Los 14 programas de `programs/` y `tests/` dan exactamente la salida de MARS, con **0 nets en error** y HALT correcto. `tools/run_tests.py` da **14/14**; `salida-tests.txt`, `informe.md` e `informe.pdf` (9 páginas A4) están generados. **No se ha subido el repositorio.**

---

## 1. Objetivo

Implementar una CPU multiciclo S-MIPS dentro de `circuit/smips.circ`, con la jerarquía obligatoria de `docs/guide.tex`, sin VHDL, sin modificar `Board`/`Memory` ni los 10 pines de `CPU`. El usuario escribe `tests/*.asm` y el informe; el agente mantiene circuito, herramientas y verificación.

## 2. Especificación operativa vigente

- **Jerarquía:** `CPU → Instruction_Decoder, Control_Unit, Branch_Control, Datapath`; `Datapath → Register_File, ALU`.
- **Sin VHDL** (0 de las 2 entidades permitidas).
- **ISA:** 23 instrucciones S-MIPS + `addu`/`addiu`. Una sola ALU, sin sumadores extra.
- **Reset:** PC=0, `$gp=0x1800`, `$sp=0x3FFC`, resto a 0; `MEM_WE=TTY_WE=HALT=0`.
- **Memoria:** 16 KiB, little-endian, lectura combinacional; `sw`→`BE=1111`, `sb`→un byte, `lb`/`lbu` extraen y extienden el byte `d[1:0]`.
- **syscall 11:** `TTY_DATA = $a0[6:0]`, `TTY_WE=1` un flanco. **syscall 10:** `HALT=1` permanente.
- **Pines CPU:** CLK (230,140), RESET (230,190), MEM_RDATA (230,240); MEM_ADDR (900,140), MEM_WDATA (900,240), MEM_BE (900,340), MEM_WE (900,390), TTY_DATA (900,440), TTY_WE (900,490), HALT (900,540).
- **FSM:** 9 estados (FETCH=0, DECODE=1, EXEC=2, MEM=3, WB=4, BRANCH=5, JUMP=6, SYS=7, HALT=8). En trazas se observan ≈4 ciclos para R/I y ≈3 para ramas/saltos; `lw`/`sw`/syscall añaden sus estados (≈5/4/3), coherente con la FSM.
- **ALUOps:** 0=ADD, 1=SUB, 2=AND, 3=OR, 4=SLT, 5=SLL, 6=SRL, 7=PASS_A, 8=PASS_B.
- **ExtType[2]:** 0=SignExt, 1=ZeroExt, 2=LUI, 3=SignExt<<2.
- **Interfaces** (pines de subcircuito, sin cambios):
  - `ALU`: in A[32], B[32], ALUOp[4]; out Result[32], Zero.
  - `Register_File`: in CLK, RESET, RS[5], RT[5], WriteAddr[5], WriteData[32], RegWrite; out ReadData1[32], ReadData2[32].
  - `Instruction_Decoder`: in Op[6], Funct[6]; out Class[5], ALUOp[4], ExtType[2], RegDst, MemToReg, LoadType[2], StoreType, BranchType[2], JumpType[2], ALUASrc[2], ALUBSel[2], Illegal, IsSyscall.
  - `Control_Unit`: 17 entradas (CLK, RESET, DEC_OUT, A[32], BranchTaken); 22 salidas (PCWrite, IRWrite, AWrite, BWrite, ALUOutWrite, MDRWrite, RegWrite, MemWrite, TTYWrite, HALT, MemAddrSrc, ALUASrc[2], ALUBSrc[3], ALUOp[4], ExtType[2], RegDst, MemToReg, LoadType[2], StoreType, IsJal, IsSyscall, BranchType[2]).
  - `Branch_Control`: in A[32], B[32], BranchType[2]; out Taken.
  - `Datapath`: 28 pines (CLK, RESET, MEM_RDATA[32] + 17 controles; salidas MEM_ADDR[32], MEM_WDATA[32], MEM_BE[4], TTY_DATA[7], IR[32], A[32], B[32]).
- **Nets internos principales de Datapath:** `PC, IR, A, B, ALUOut, MDR, RF_ReadData1/2, ALU_A, ALU_B, DP_WriteAddr, DP_WriteData, IR_RS/RT/RD/SHAMT/IMM16/JADDR, IMM_SIGNED/IMM_ZEROED/IMM_LUI/IMM_BRANCH/IMM_EXT, JMP_DIR32/JMP_DIR_SHIFTED/JMP_PC_HIGH/JMP_TARGET, MEM_ADDR/MEM_WDATA/MEM_BE, TTY_DATA, SB_DATA/SB_BE, LOAD_LB/LBU/…, ZERO32, CONST_*`.
- **Bibliotecas XML:** WIRING=0, GATES=1, PLEXERS=2, ARITH=3, MEMORY=5, BASE=7.

## 3. Estado de archivos

| Archivo | Descripción | SHA-256 |
|---|---|---|
| `circuit/smips.circ` | Circuito corregido y verificado (413 844 B) | `4ae89a333ab90fee6d7155908620959511d82e27d89d997af1bc36b6deba4252` |
| `circuit/smips.circ.bak` | **Copia de seguridad** del estado anterior (404 851 B) | `8375b47334ca1e47412d8707e0afae2a8d82c0b5b5a831563b0dbdf3542187f5` |

Comparación estructural contra el backup: **`Board`, `Memory`, `CPU`, `Control_Unit` y `Branch_Control` son idénticos**; los 10 pines de CPU coinciden en nombre, posición, ancho y sentido (R2). Solo cambiaron `ALU`, `Instruction_Decoder`, `Register_File` y `Datapath`.

## 4. Correcciones aplicadas el 2026-11-16

### 4.1 Nueve constantes huérfanas (causa principal)

Al mover componentes en Logisim, los cables no se desplazan con ellos: 9 `Constant` quedaron sin ningún cable. Se reconectaron con cable + túnel (separación ≥30 px, sin solapes):

| Circuito | Constante | Túnel | Posición |
|---|---|---|---|
| Register_File | (120,1470) 0x0 32b | `RF_ZERO32` | (150,1470) |
| Register_File | (120,1570) 0x1800 | `RF_GP` | (150,1570) |
| Register_File | (120,1670) 0x3FFC | `RF_SP` | (150,1670) |
| Register_File | (120,1770) 0x0 1b | `RF_ZERO1` | (150,1770) |
| ALU | (510,700) 0x0 1b | `ZERO1` | (540,700) |
| ALU | (550,670) 0x0 32b | `ZERO32` | (580,670) |
| Instruction_Decoder | (520,1020) 0x0 5b | `DEC_ZERO5` | (480,1020) |
| Instruction_Decoder | (600,1020) 0x0 1b | `K0` | (630,1020) |
| Instruction_Decoder | (600,1120) 0x0 1b | `K1` | (630,1120) |

Efectos que tenían: lectura de `$zero` indefinida (`U`), `$gp`/`$sp` sin valores iniciales, `Zero` de la ALU inválido, entradas 9..15 del mux de resultado flotantes, y `BranchType[1]=U` (por `K0`) → `BR_Taken=E` desde el ciclo 1.

### 4.2 Etiquetas intercambiadas en el camino del inmediato (Datapath)

- Túnel `(1360,40)`: `IMM_SIGNED` → **`IMM_EXT`** (salida del mux `ExtType (1340,40)`).
- Túnel `(1390,140)`: `IMM_EXT` → **`IMM_SIGNED`** (salida del `Bit Extender (1370,140)`, type=sign).

Antes, la salida del mux alimentaba su propia entrada 0 (`IMM_SIGNED`) y la entrada 3 (`IMM_BRANCH`, vía `Shifter (1660,270)`) → lazo combinacional que mantenía `IMM_SIGNED`/`IMM_BRANCH` en `E`.

### 4.3 Enable del decodificador de escritura del banco de registros

`Register_File`, `Decoder (1380,1540)`: `enable` pasa de `false` a **`true`**. El cableado ya existía (`RegWrite (1310,1540)` → `(1370,1540)`, justo el pin de Enable). Con `enable=false` las 32 salidas estaban siempre activas y **se escribía un registro en cada flanco** usando el `WriteAddr`/`WriteData` presentes, corrompiendo registros (p. ej. `$t1` se sobrescribía con el valor viejo de `$t0`). Por eso `gcd`/`multiply` fallaban y `hello`/`array_sum` parecían funcionar por casualidad.

### 4.4 Por qué se veía “cortocircuito” en `TTY_DATA` y `MEM_WDATA`

No hay dos drivers sobre esas nets (anchos 7 y 32 correctos). Mostraban `U`/`E` porque heredaban el error de los puntos 4.1–4.3; al corromperse el estado (PC/registros con `E`), esos buses aparecían en rojo. El único lazo real era el de `IMM_SIGNED`.

## 5. Verificación funcional (archivo ya corregido)

Método: carga *headless* con Logisim 5.0.0, `AutoPropagation=false`, `toggleClocks()` + `propagate()` por ciclo, sin GUI; comparación con MARS (`java -Djava.awt.headless=true -jar Mars4_5.jar nc mc CompactTextAtZero prog.asm`).

### 5.1 Programas entregados

| Programa | Salida CPU | MARS | Ciclos | Nets en error |
|---|---|---|---|---|
| `hello.asm` | `Hola, S-MIPS` | igual | 283 | 0 |
| `array_sum.asm` | `Suma: 23` | igual | 884 | 0 |
| `multiply.asm` | `120 156` | igual | 1 918 | 0 |
| `gcd.asm` | `12 / 1 / 9 / 6` | igual | 2 757 | 0 |

### 5.2 Programas propios (`tests/`, cobertura R21)

Siete programas propios (imágenes en `images/t0*.hex`) que, entre todos, cubren
todas las filas de `tab:casos`:

| Programa | Cubre | Salida | Ciclos |
|---|---|---|---|
| `t01_aritmetica.asm` | add/sub con positivos y negativos; addi negativo; slt y slti 1/0 con negativos; addiu y addu vía `li`/`move` | 3 líneas hex | 3490 |
| `t02_logica.asm` | and/or con unos en los 16 bits altos; andi/ori con bit 15 = 1; lui con bit 15 = 1 | `0f0f000f fffff0ff 00008000 00008000 80010000` | 1605 |
| `t03_memoria.asm` | lw/sw con desplazamiento 0/±; lb/lbu con bit 7 en las posiciones 3 y 2; sb en los 4 carriles y comprobación con lw | 2 líneas hex | 3217 |
| `t04_saltos.asm` | beq/bne tomados y no tomados; bucle y j hacia atrás y adelante | `AB01201C` | 262 |
| `t05_tty.asm` | lbu/beq/j; syscall 11/10; escrituras en `$zero` con add/addi/ori/lui/lw | `OK0` | 146 |
| `t06_desplaz.asm` | sll/srl con shamt 0 y ≠0; srl y sll de un negativo | 2 líneas hex | 1920 |
| `t07_llamadas.asm` | jal/jr con procedimiento no hoja (`suma` recursiva) y `$ra` en la pila | `0000000a` | 550 |

`python3 tools/run_tests.py` ejecuta 7 de `programs/` + 7 de `tests/`:
**14/14 correctos** y 0 nets en error. La tabla de cobertura fila → programa
está en el informe (sección 7).

### 5.3 Comprobaciones estructurales

- 0 componentes huérfanos, 0 nets con más de un driver, 0 conflictos de ancho.
- 0 nets en `E` durante todas las ejecuciones.
- 9 túneles nuevos: bbox comprobado contra los bounds reales de Logisim, **0 solapes** (las etiquetas se dibujan al lado opuesto del atributo `facing`; se dejó sin `facing` para que vayan a la derecha, y `DEC_ZERO5` con `facing=east` para que vaya a la izquierda, lejos de las constantes).

## 6. Pendiente / próximos pasos

1. **`tests/` (R21):** **completo**. Siete programas propios (`t01`–`t07`) con sus imágenes cubren todas las filas de `tab:casos`; verificado con MARS y con la CPU.
2. **`tools/run_tests.py`:** **corregido y verificado**. Compila `Run.java` y ejecuta la clase; por defecto sin ventana (`--con-ventana` para VHDL). Resultado final: **14/14**.
3. **`salida-tests.txt`:** **generado** con la salida completa final (14/14).
4. **`informe.md` e `informe.pdf`:** **generados**. PDF A4 de 9 páginas (≤10), con las 8 secciones exigidas, la figura de la ruta de datos, las tablas de FSM/señales/codificación/ciclos/cobertura y los resultados y limitaciones.
5. **Etiquetar los 9 pines de salida sin nombre de `Control_Unit`**: `ALUASrc`, `ALUOp`, `ExtType`, `RegDst`, `MemToReg`, `LoadType`, `StoreType`, `IsSyscall`, `BranchType` (funcionan por posición, pero se ven en blanco en la instancia de la CPU; criterio de claridad/defensa).
6. **Opcional:** medir formalmente R4/R5 (`TTY_WE` exactamente un flanco por carácter; `MEM_WE` solo en `sw`/`sb`) y dejar constancia en el informe. El funcionamiento actual es correcto en las pruebas, pero conviene registrarlo.
7. **Opcional:** revisar el resto del layout por solapes (más allá de los túneles corregidos).
8. **Entrega:** decidir si `circuit/smips.circ.bak` se conserva (material extra permitido) o se excluye del commit final; actualmente no está versionado.

## 7. Herramientas, rutas y notas de implementación

- **Logisim:** `~/Downloads/logisim-evolution-5.0.0-all.jar` (5.0.0).
- **MARS:** `~/Apps/mars/Mars4_5.jar` (4.5.1); usar `-Djava.awt.headless=true` para consola.
- **JDK:** `~/.local/share/ElyPrismLauncher/java/java-runtime-epsilon/bin` (JDK 25, con `javac`).
- **`tools/Ports.java`:** funciona *headless*; da, por circuito, fábrica, posición, índice de puerto, tip, coordenadas, ancho, tipo (1=IN, 2=OUT, 3=INOUT) y bounds. `javac -cp JAR -d /tmp/cls tools/Ports.java` + `java -Djava.awt.headless=true -cp JAR:/tmp/cls Ports circuito.circ`.
- **Simulación headless:** cargar con `Loader`, `new Project(file)`, `setAutoPropagation(false)`, `setAutoTicking(false)`, `simulator.shutDown()` + `join(5000)`, `CircuitState.createRootState(project, file.getCircuit("Board"), Thread.currentThread())`, `project.setCircuitState(state)`; ciclar con `propagator.toggleClocks()` + `propagate()`. `tools/Run.java` ya no crea `Frame` si no hay VHDL, así que puede ejecutarse sin pantalla; con VHDL/Questa sí requiere `DISPLAY`.
- **`tools/run_tests.py`:** compila `Run.java` con `javac` en un directorio temporal y ejecuta la clase `Run` (no modo fuente). Por defecto usa `-Djava.awt.headless=true`; `--con-ventana` (o `SMIPS_HEADLESS=0`) para VHDL. Descubre Logisim/JDK/MARS por variables de entorno o rutas habituales.
- **`tools/assemble.py`:** ensambla con MARS añadiendo `-Djava.awt.headless=true`; genera la imagen `v3.0 hex words addressed` con `.text` en 0x000 y `.data` en 0x800 (byte 0x2000). Avisa de instrucciones fuera de S-MIPS.
- **Harness de verificación:** el usado en estas pruebas es el propio `tools/run_tests.py` + `tools/Run.java`; ya no hacen falta variantes en `/tmp`.
- **Túneles en Logisim:** la etiqueta se dibuja **al lado opuesto** de `facing` (facing=east → etiqueta a la izquierda; sin `facing` → a la derecha). Al añadir túneles, comprobar los bounds reales con `Ports.java` para no tapar textos/componentes.
- **Mover componentes en Logisim no mueve los cables:** causa típica de señales flotantes (fue el origen de 4.1). Tras mover algo, reconectar y volver a verificar.
- **`E` (rojo) ≠ cortocircuito de la net:** puede ser un lazo combinacional o el arrastre de una señal flotante; localizar el driver real con un netlist (unión de cables + túneles por etiqueta) y `propagate()`.
- **Generador histórico:** no ejecutar `build.py`; reconstruye el circuito desde cero y borraría el `Datapath`/`Control_Unit` manuales y estas correcciones.
- **Pines de `Control_Unit`:** las entradas usan prefijo `CI_` para no colisionar con las salidas; las salidas usan su nombre nativo o `CI_<nombre>`.
- **`Register_File`:** mux de lectura entrada 0 = `RF_ZERO32`; escritura con decoder `enable=true` habilitado por `RegWrite`; `$gp`/`$sp` con mux de reset a 0x1800/0x3FFC.

## 8. Historial breve

1. Lectura de la especificación y herramientas; verificación de Logisim 5.0.0 y MARS; `assemble.py` probado con `hello.asm`.
2. El generador histórico (ya retirado de `tools/`) creó la jerarquía e interfaces de los seis subcircuitos.
3. ALU, Register_File, Instruction_Decoder y Branch_Control validados con harnesses Java (add/sub/and/or/slt/sll/srl/Zero; reset y lectura/escritura del RF; 26 casos de decoder; ramas).
4. El usuario completó manualmente el `Datapath` y el `Control_Unit` y ajustó el cableado (la mayor parte del circuito actual es suya).
5. 2026-11-16: diagnóstico de los fallos (constantes huérfanas, etiquetas intercambiadas y decoder de escritura sin Enable), backup, corrección y verificación completa (13/13, 0 errores). CPU operativa.
6. 2026-11-23: creados `tests/t01`–`t05` (5 programas sencillos) con sus imágenes; `run_tests.py` compila y ejecuta `Run.java` como clase y funciona sin ventana; `Run.java` ya no crea `Frame` sin VHDL; `assemble.py` ejecuta MARS headless. Resultado: **12/12 correctos**.
7. 2026-11-24: `tests/` ampliado a 7 programas con cobertura total de `tab:casos`; **14/14**; `salida-tests.txt`; `informe.md` e `informe.pdf` (9 páginas A4, figura de ruta de datos en `images/informe_datapath.png`). Sin push del repositorio.

## 9. Archivos relevantes

- `circuit/smips.circ` — circuito principal corregido.
- `circuit/smips.circ.bak` — copia de seguridad previa a las correcciones.
- `docs/guide.tex` / `docs/guide.pdf` — especificación completa.
- `README.md` — resumen de placa y flujo.
- `programs/*.asm`, `images/*.hex` — programas e imágenes de referencia.
- `tests/t01_aritmetica.asm` … `tests/t07_llamadas.asm` — programas propios con cobertura R21; imágenes en `images/t0*.hex`.
- `informe.md` / `informe.pdf` — informe del proyecto (9 páginas A4).
- `salida-tests.txt` — salida completa de `run_tests.py` (14/14).
- `images/informe_datapath.svg` — **fuente editable** de la figura (Inkscape o editor de texto).
- `images/informe_datapath.png` — figura de la ruta de datos usada en el informe (se regenera desde el SVG).
- `tools/assemble.py` — ensambla con MARS (headless) y genera la imagen de RAM.
- `tools/run_tests.py` — compila `Run.java` y compara la CPU con MARS; `--con-ventana` para VHDL.
- `tools/Run.java` — simulador de la placa; sin ventana cuando no hay VHDL.
- `tools/Ports.java` — descubre puertos y bounds (funciona headless).
- `tools/build.py` — generador original de Board/Memory/CPU (referencia XML).
8. 2026-11-24: figura de ruta de datos ajustada a mano: PC→ALU sale por abajo, IR→Decoder 3 mm más abajo, ALUOut→Mux PC sale por el lateral derecho con la etiqueta al lado, etiquetas MEM_RDATA recolocadas y flecha CU↔Branch_Control rotulada BranchType/Taken. La fuente editable es `images/informe_datapath.svg`; el PNG y el PDF se regeneraron durante la preparación. PDF final: 9 páginas A4.

## 10. Revisión final (2026-11-24)

- **14/14** programas correctos; `salida-tests.txt` es idéntico a la última ejecución.
- `circuit/smips.circ`: `Board`, `CPU` y `Memory` coinciden exactamente con `smips.circ.bak`; se restauró `simulationFrequency` del `Board` a 1.0 (R2).
- `informe.md`/`informe.pdf` corregidos: mux del PC = `IsJal` (ALUOut solo en WB de `jal`), salida de JUMP, FSM ya no se describe como Moore pura, tabla 4.4 con las señales del decodificador por estado y etiqueta `ALU / ALUOut (jal)` en la figura. PDF: 9 páginas A4.
- `README.md` actualizado: ya no dice que la CPU está vacía ni que `tests/` está por crear; advierte que `build.py` es histórico y destructivo.
- **Única desviación funcional conocida:** en una instrucción ilegal el PC queda en PC+4 (se incrementa en FETCH antes de detectarla en DECODE); registros y memoria no se modifican. Está declarada en el informe (8.2) y en la conclusión. No se cambió la lógica para no arriesgar la CPU ya verificada.
- **No se hizo commit ni push.**
- **Imágenes:** 14 `.hex` en `images/` (7 de `programs/` + 7 de `tests/`). Faltaban `arithmetic`, `branches` y `memory`; se generaron con `assemble.py` y coinciden con las de la referencia porque esos programas son material entregado.
