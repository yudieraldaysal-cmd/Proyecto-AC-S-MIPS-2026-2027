---
title: "Informe del Proyecto: CPU multiciclo S-MIPS en Logisim Evolution"
author: "Yudier Alday Salgado"
date: "Curso 2026-2027 — 24 de noviembre de 2026"
lang: es
---

# 1. Nombre y VHDL

**Autor:** Yudier Alday Salgado. **Curso:** 2026-2027.

**VHDL:** no se empleó VHDL para ningún subcircuito de la CPU. Los seis
subcircuitos obligatorios (`Instruction_Decoder`, `Control_Unit`,
`Branch_Control`, `Datapath`, `Register_File` y `ALU`) son circuitos de
Logisim. La decisión permite controlar y explicar directamente el cableado y
las señales, no necesita Questa y cumple el límite de R18 (0 de las 2
entidades permitidas).

# 2. Ruta de datos

La CPU es multiciclo: ejecuta una instrucción a la vez, con **una sola ALU**,
una sola memoria para instrucciones y datos, y registros intermedios que
conservan los operandos entre ciclos. La jerarquía es:

- `CPU` contiene `Instruction_Decoder`, `Control_Unit`, `Branch_Control` y
  `Datapath`.
- `Datapath` contiene `Register_File` y `ALU`.

![Figura 2.1. Ruta de datos. Los nombres en cada bloque son las señales de
control que lo gobiernan; la tabla 2.1 detalla todos los bloques y señales.](images/informe_datapath.png){width=16cm}

## 2.1. Componentes y señales que los gobiernan

| Componente | Función | Señales de control |
|---|---|---|
| PC (32 bits) | Dirección de la instrucción. Se carga en FETCH con PC+4, y en BRANCH/JUMP/WB con el destino correspondiente. `RESET` lo borra. | `PCWrite` |
| Mux del PC | Elige el valor que entra al PC: resultado de la ALU (FETCH, BRANCH y JUMP `j`/`jr`) o ALUOut (WB de `jal`). | `IsJal` |
| Mux de MEM_ADDR | Dirección de memoria: PC (búsqueda de instrucción) o ALUOut (dato de `lw`/`sw`). | `MemAddrSrc` |
| IR (32 bits) | Guarda la instrucción durante todos sus ciclos. | `IRWrite` |
| `Instruction_Decoder` | Combinacional. Decodifica op y funct: clase, operación de ALU, extensión, destinos y modificadores. Detecta lo ilegal. | — |
| `Register_File` | 31 registros de 32 bits más `$zero` cableado a 0. Dos lecturas combinacionales y una escritura en flanco. `$gp=0x1800`, `$sp=0x3FFC`. | `RegWrite`, `RS`, `RT`, `WriteAddr`, `WriteData` |
| A (RS) y B (RT) | Guardan los datos leídos del banco para usarlos en los ciclos siguientes. | `AWrite`, `BWrite` |
| Mux del operando A | Elige RS, RT o PC. | `ALUASrc` |
| Mux del operando B | Elige RT, inmediato extendido, shamt, constante 4 o `JMP_TARGET`. | `ALUBSrc` |
| Extensor del inmediato | Extensión con signo, con ceros, LUI o signo desplazado a la izquierda 2. | `ExtType` |
| `ALU` | Única ALU. Operaciones aritméticas, lógicas, comparación y desplazamientos. Salida `Zero`. | `ALUOp` |
| ALUOut | Guarda el resultado de la ALU o la dirección calculada. | `ALUOutWrite` |
| MDR | Guarda la palabra leída de memoria. | `MDRWrite` |
| Datos de carga | Para `lw` usa la palabra de MDR; para `lb`/`lbu` extrae el byte `ALUOut[1:0]` de MDR y lo extiende con signo o con ceros. | `LoadType` |
| Mux de WriteAddr | Destino en el banco: rt, rd o `$31` para `jal`. | `RegDst`, `IsJal` |
| Mux de WriteData | Dato a escribir: ALUOut, dato de carga o PC (para `jal`). | `MemToReg`, `IsJal` |
| MEM_WDATA y MEM_BE | `sw`: B y `1111`. `sb`: el byte bajo de B en el carril `ALUOut[1:0]` y `MEM_BE = 1 << ALUOut[1:0]`. | `StoreType` |
| TTY | `TTY_DATA = B[6:0]` con `TTY_WE` durante un ciclo. | `TTYWrite` |
| `Branch_Control` | Compara A y B y decide si el branch se toma. | `BranchType` |
| `Control_Unit` | FSM de 9 estados: calcula el siguiente estado y todas las señales de control. | — |

## 2.2. Uso de la única ALU en cada estado

| Estado | Uso de la ALU |
|---|---|
| FETCH | `PC + 4` con A = PC y B = 4; el resultado va directo al mux del PC. |
| DECODE | No se escribe ALUOut: se cargan A y B desde el banco. |
| EXEC | Operación de la instrucción según el decodificador: A = RS o RT, B = RT, inmediato o shamt. |
| MEM | No se usa: la dirección ya está en ALUOut. |
| WB | No se usa. |
| BRANCH | `PC + 4 + (SignExt(imm) << 2)` con A = PC y B = inmediato extendido; el resultado va directo al mux del PC. |
| JUMP | `PASS_B` con B = `JMP_TARGET` para `j`/`jal`, o `PASS_A` con A = RS para `jr`. El resultado se guarda en ALUOut; en `j`/`jr` el PC toma el resultado directo de la ALU y en `jal` se usa ALUOut en WB. |
| SYS / HALT | No se usa. |

`PC+4`, el destino de los branches, el destino de los saltos y las direcciones
de memoria se calculan con la misma ALU en ciclos distintos; no hay otro
sumador en la CPU.

## 2.3. Memoria y bytes

La memoria entrega la palabra completa que contiene `MEM_ADDR` (elige con
`MEM_ADDR[13:2]`) y es little-endian. En `lw` el dato es la palabra completa.
En `lb` y `lbu` el Datapath toma el byte `ALUOut[1:0]` de MDR y lo extiende con
signo o con ceros, respectivamente. En `sb` el byte bajo de B se coloca en el
carril `ALUOut[1:0]` y `MEM_BE` activa solo ese carril, de modo que los otros
tres bytes de la palabra no cambian.

## 2.4. Decisiones de diseño

- Registros A, B y MDR: la CPU es multiciclo y los operandos y el dato leído
  deben sobrevivir hasta el ciclo en que se usan.
- El PC se escribe en FETCH con PC+4; por eso `jal` conserva PC+4 en el PC
  hasta WB, donde el banco escribe el PC en `$31` y el PC se carga con el
  destino.
- `j` y `jal` forman el destino con cableado (`JMP_TARGET`), sin sumador; `jr`
  pasa RS a través de la ALU.
- `Branch_Control` usa un comparador de igualdad en lugar de la salida Zero de
  la ALU; así la ALU queda libre para calcular el destino del branch.
- En `syscall`, el Datapath fuerza RS=2 (`$v0`) y RT=4 (`$a0`); la Control_Unit
  compara A con 10 y 11 para decidir HALT o imprimir.

# 3. Máquina de estados

La `Control_Unit` contiene una FSM síncrona: un registro de 4 bits (con Clear
conectado a RESET, que la lleva a FETCH) y lógica combinacional para el
siguiente estado y las salidas. Las salidas dependen del estado y también del
decodificador, de `Taken` y de `$v0`, así que no es una FSM de Moore pura. La codificación de estados es la
siguiente.

| Estado | Código | Siguiente estado y condición |
|---|---|---|
| FETCH | 0000 | DECODE |
| DECODE | 0001 | EXEC si es R, I-ALU, desplazamiento o LUI; MEM si es carga o almacenamiento; BRANCH si es `beq`/`bne`; JUMP si es `j`/`jal`/`jr`; SYS si es `syscall`; HALT si `Illegal = 1` |
| EXEC | 0010 | WB si no accede a memoria; MEM si es carga o almacenamiento |
| MEM | 0011 | WB si es carga; FETCH si es almacenamiento |
| WB | 0100 | FETCH |
| BRANCH | 0101 | FETCH |
| JUMP | 0110 | FETCH para `j`/`jr`; WB para `jal` |
| SYS | 0111 | HALT si `$v0 = 10`; FETCH en otro caso |
| HALT | 1000 | HALT (permanece hasta el reset) |

`Branch_Control` calcula
`Taken = (BranchType = 00 ∧ A = B) ∨ (BranchType = 01 ∧ A ≠ B)`.
En BRANCH, `PCWrite = Taken`; si el branch no se toma, el PC ya vale PC+4
desde FETCH y la ejecución continúa en la instrucción siguiente. En JUMP,
`PCWrite = 1` para `j`/`jr` y `0` para `jal` (el PC se escribe en WB, junto con
`$31`). En FETCH, `PCWrite = 1` escribe PC+4.

# 4. Señales de control por estado

Leyenda: **0/1** = valor fijo; **D** = valor que entrega el decodificador;
**T** = depende de `Taken`; **st** = 1 en almacenamiento (`sw`/`sb`) y 0 en
carga; **jal** = 1 en `jal` y 0 en el resto; **v11** = 1 si `$v0 = 11`. Un
guion (—) indica que la señal no influye en ese estado. `MemWrite` y `TTYWrite`
son las señales internas que salen por los pines `MEM_WE` y `TTY_WE`.

## 4.1. Escrituras y control del PC

**4.1a. PCWrite, IRWrite, AWrite y BWrite**

| Estado | PCWrite | IRWrite | AWrite | BWrite |
|---|---|---|---|---|
| FETCH | 1 | 1 | 0 | 0 |
| DECODE | 0 | 0 | 1 | 1 |
| EXEC | 0 | 0 | 0 | 0 |
| MEM | 0 | 0 | 0 | 0 |
| WB | jal | 0 | 0 | 0 |
| BRANCH | T | 0 | 0 | 0 |
| JUMP | 1 si j/jr; 0 si jal | 0 | 0 | 0 |
| SYS | 0 | 0 | 0 | 0 |
| HALT | 0 | 0 | 0 | 0 |

**4.1b. ALUOutWrite, MDRWrite, RegWrite y MemWrite**

| Estado | ALUOutWrite | MDRWrite | RegWrite | MemWrite |
|---|---|---|---|---|
| FETCH | 0 | 0 | 0 | 0 |
| DECODE | 0 | 0 | 0 | 0 |
| EXEC | 1 | 0 | 0 | 0 |
| MEM | 0 | 1 | 0 | st |
| WB | 0 | 0 | 1 | 0 |
| BRANCH | 0 | 0 | 0 | 0 |
| JUMP | 1 | 0 | 0 | 0 |
| SYS | 0 | 0 | 0 | 0 |
| HALT | 0 | 0 | 0 | 0 |

## 4.2. Memoria, TTY, HALT y selectores de la ALU

**4.2a. TTYWrite, HALT, MemAddrSrc e IsSyscall**

| Estado | TTYWrite | HALT | MemAddrSrc | IsSyscall |
|---|---|---|---|---|
| FETCH | 0 | 0 | 0 | 0 |
| DECODE | 0 | 0 | 0 | D |
| EXEC | 0 | 0 | 0 | 0 |
| MEM | 0 | 0 | 1 | 0 |
| WB | 0 | 0 | 0 | 0 |
| BRANCH | 0 | 0 | 0 | 0 |
| JUMP | 0 | 0 | 0 | 0 |
| SYS | v11 | 0 | 0 | 1 |
| HALT | 0 | 1 | 0 | 0 |

**4.2b. ALUASrc, ALUBSrc, ALUOp e IsJal**

| Estado | ALUASrc | ALUBSrc | ALUOp | IsJal |
|---|---|---|---|---|
| FETCH | 10 (PC) | 011 (4) | 0000 (ADD) | 0 |
| DECODE | — | — | — | 0 |
| EXEC | D | D | D | 0 |
| MEM | — | — | — | 0 |
| WB | — | — | — | jal |
| BRANCH | 10 (PC) | 001 (IMM) | 0000 (ADD) | 0 |
| JUMP | 00 (A) | 100 (JMP) si j/jal; 000 si jr | 1000 (PASS_B) si j/jal; 0111 (PASS_A) si jr | 0 |
| SYS | — | — | — | 0 |
| HALT | — | — | — | 0 |

## 4.3. Señales que vienen del decodificador

| Señal | Valores | Se usa en |
|---|---|---|
| ExtType[1:0] | 00 = signo; 01 = ceros; 10 = LUI; 11 = signo<<2 | EXEC y BRANCH |
| RegDst | 0 = rt; 1 = rd (jal fuerza 31 con `IsJal`) | WB |
| MemToReg | 0 = ALUOut; 1 = dato de carga (jal fuerza PC con `IsJal`) | WB |
| LoadType[1:0] | 0 = lw; 1 = lb; 2 = lbu | WB (y MEM) |
| StoreType | 0 = sw; 1 = sb | MEM |
| BranchType[1:0] | 0 = beq; 1 = bne | BRANCH (a `Branch_Control`) |
| IsJal | 1 en jal | JUMP y WB |
| IsSyscall | 1 en syscall | DECODE y SYS |
| Illegal | 1 si ninguna clase coincide | DECODE |

`ExtType`, `RegDst`, `MemToReg`, `LoadType`, `StoreType`, `BranchType`,
`IsSyscall` e `Illegal` son salidas del decodificador; `IsJal` lo genera la
Control_Unit a partir de la clase de `jal`. La tabla de valores por instrucción
está en la sección 5.

## 4.4. Valor de las señales del decodificador en cada estado

Estas seis señales son salidas combinacionales del decodificador; por tanto su
valor es **D** en todos los estados, aunque solo influyen en los estados que se
indican en la tabla 4.3.

| Estado | ExtType | RegDst | MemToReg | LoadType | StoreType | BranchType |
|---|---|---|---|---|---|---|
| FETCH | D | D | D | D | D | D |
| DECODE | D | D | D | D | D | D |
| EXEC | D | D | D | D | D | D |
| MEM | D | D | D | D | D | D |
| WB | D | D | D | D | D | D |
| BRANCH | D | D | D | D | D | D |
| JUMP | D | D | D | D | D | D |
| SYS | D | D | D | D | D | D |
| HALT | D | D | D | D | D | D |

# 5. Codificación de la ALU y del decodificador

## 5.1. Operaciones de la ALU

| ALUOp | Operación | Detalle |
|---|---|---|
| 0000 | ADD | Suma |
| 0001 | SUB | Resta |
| 0010 | AND | Bit a bit |
| 0011 | OR | Bit a bit |
| 0100 | SLT | Comparación con signo; resultado 0/1 extendido con ceros |
| 0101 | SLL | Desplazamiento lógico a la izquierda; shamt en B[4:0] |
| 0110 | SRL | Desplazamiento lógico a la derecha; entran ceros |
| 0111 | PASS_A | Deja pasar A |
| 1000 | PASS_B | Deja pasar B |

La salida `Zero` vale 1 cuando `Result = 0`; se calcula con un comparador
unsigned contra 0. El multiplexor de resultado es de 16 entradas; las no
usadas se conectan a la constante 0.

## 5.2. Tipos de extensión

| ExtType | Extensión |
|---|---|
| 00 | SignExt: repite el bit 15 |
| 01 | ZeroExt: rellena con ceros |
| 10 | LUI: `{imm, 0000}` |
| 11 | SignExt(imm) << 2 (destino de branch) |

## 5.3. Clases del decodificador

| Clase | Instrucción(es) | op / funct | ALUOp | ExtType |
|---|---|---|---|---|
| 0 | `add`, `addu` | 00 / 20, 21 | 0000 | 00 |
| 1 | `sub` | 00 / 22 | 0001 | 00 |
| 2 | `and` | 00 / 24 | 0010 | 00 |
| 3 | `or` | 00 / 25 | 0011 | 00 |
| 4 | `slt` | 00 / 2A | 0100 | 00 |
| 5 | `sll` | 00 / 00 | 0101 | 00 |
| 6 | `srl` | 00 / 02 | 0110 | 00 |
| 7 | `addi`, `addiu` | 08, 09 | 0000 | 00 |
| 8 | `slti` | 0A | 0100 | 00 |
| 9 | `andi` | 0C | 0010 | 01 |
| 10 | `ori` | 0D | 0011 | 01 |
| 11 | `lui` | 0F | 1000 | 10 |
| 12 | `lw` | 23 | 0000 | 00 |
| 13 | `sw` | 2B | 0000 | 00 |
| 14 | `lb` | 20 | 0000 | 00 |
| 15 | `lbu` | 24 | 0000 | 00 |
| 16 | `sb` | 28 | 0000 | 00 |
| 17 | `beq` | 04 | 0001 | 11 |
| 18 | `bne` | 05 | 0001 | 11 |
| 19 | `j` | 02 | 0000 | 00 |
| 20 | `jal` | 03 | 0000 | 00 |
| 21 | `jr` | 00 / 08 | 0111 | 00 |
| 22 | `syscall` | 00 / 0C | 0000 | 00 |

En `beq`/`bne`, la Control_Unit sobrescribe `ALUOp` con 0000 en BRANCH para
sumar el destino; el comparador de igualdad decide el salto. En `jr`, la
Control_Unit sobrescribe `ALUASrc` con 00 para pasar RS a través de la ALU.

## 5.4. Campos del decodificador

| Campo | Codificación |
|---|---|
| ALUASrc[1:0] | 00 = RS (A); 01 = RT (B); 10 = PC |
| ALUBSel[2:0] | 000 = B (RT); 001 = inmediato extendido; 010 = shamt; 011 = constante 4; 100 = `JMP_TARGET` |
| RegDst | 0 = rt; 1 = rd |
| MemToReg | 0 = ALUOut; 1 = memoria (carga) |
| LoadType[1:0] | 0 = lw; 1 = lb; 2 = lbu |
| StoreType | 0 = sw; 1 = sb |
| BranchType[1:0] | 0 = beq; 1 = bne |
| JumpType[1:0] | 0 = j; 1 = jal; 2 = jr (la Control_Unit usa la clase para elegir el salto) |
| IsSyscall | 1 = syscall; 0 = resto |
| Illegal | 1 = par (op, funct) fuera de la tabla |

El decodificador identifica la instrucción por `op` y, si `op = 0`, por
`funct`. `addu` se decodifica como `add` y `addiu` como `addi`. La palabra
`0x00000000` es `sll $zero,$zero,0` (nop) y es legal. Si ninguna clase coincide,
`Illegal = 1` y la Control_Unit pasa a HALT en DECODE.

# 6. Ciclos por clase de instrucción

Los ciclos se midieron siguiendo la secuencia de estados de la FSM en
programas de prueba.

| Clase | Instrucciones | Estados | Ciclos |
|---|---|---|---|
| R, I-ALU, desplazamiento, LUI | `add`, `addu`, `sub`, `and`, `or`, `slt`, `sll`, `srl`, `addi`, `addiu`, `slti`, `andi`, `ori`, `lui` | FETCH, DECODE, EXEC, WB | 4 |
| Carga | `lw`, `lb`, `lbu` | FETCH, DECODE, EXEC, MEM, WB | 5 |
| Almacenamiento | `sw`, `sb` | FETCH, DECODE, EXEC, MEM | 4 |
| Branch | `beq`, `bne` | FETCH, DECODE, BRANCH | 3 |
| `j` y `jr` | `j`, `jr` | FETCH, DECODE, JUMP | 3 |
| `jal` | `jal` | FETCH, DECODE, JUMP, WB | 4 |
| `syscall` 11 | `syscall` con `$v0 = 11` | FETCH, DECODE, SYS | 3 |
| `syscall` 10 | `syscall` con `$v0 = 10` | FETCH, DECODE, SYS, HALT | 4 hasta HALT |
| Otro `syscall` | `$v0` distinto de 10 y 11 | FETCH, DECODE, SYS | 3 (continúa) |
| Instrucción ilegal | par (op, funct) no válido | FETCH, DECODE, HALT | 3 hasta HALT |

El programa más largo de la batería (`programs/arithmetic.asm`) tarda 6315
ciclos, muy por debajo del límite de 60 000.

# 7. Cobertura de tests

Los programas de `tests/` son propios y cubren todas las filas de la tabla de
casos de la guía. Cada uno imprime valores calculados (no solo un mensaje) y
termina con `syscall` 10. Las imágenes correspondientes están en `images/`.

| Instrucciones / caso exigido | Cómo se cubre | Programa |
|---|---|---|
| `add`, `sub` con positivos y con un operando negativo | 1000+250, 1000+(−7), 1000−250, (−7)−1000 | `t01_aritmetica.asm` |
| `and`, `or` con unos en los 16 bits altos | `0xFFFF00FF & 0x0F0FF00F` y `0xFFFF00FF OR 0x0F0FF00F` | `t02_logica.asm` |
| `slt`, `slti`: resultado 1 y 0; negativo donde signo y sin signo difieren | (−7)<1000 → 1, 1000<(−7) → 0; slti (−7)<(−6) → 1, 1000<(−1) → 0 | `t01_aritmetica.asm` |
| `sll`, `srl`: shamt 0 y ≠ 0; `srl` de un negativo | sll 0/4, srl 0/4/31 sobre −7 | `t06_desplaz.asm` |
| `addi` con inmediato negativo | 9+(−4) y −3 | `t01_aritmetica.asm` |
| `addiu`, `addu` mediante `li` y `move` | `li $a0,-5`; `move $a0,$s0` | `t01_aritmetica.asm` |
| `andi`, `ori` con inmediato con bit 15 = 1 | `andi 0x8000`, `ori 0x8000` (extensión con ceros) | `t02_logica.asm` |
| `lui` con bit 15 = 1 | `lui $a0,0x8001` | `t02_logica.asm` |
| `lw`, `sw` con desplazamiento positivo y negativo | `sw/lw 4($s1)` y `sw/lw -4($s2)` | `t03_memoria.asm` |
| `lb`, `lbu` con bit 7 = 1 en dos posiciones | posiciones 3 y 2 de `0x80E97F11` | `t03_memoria.asm` |
| `sb` en las 4 posiciones, comprobando los otros bytes con `lw` | `0xddccbbaa` y `0x12ff5678` | `t03_memoria.asm` |
| `beq`, `bne` tomados y no tomados; salto hacia atrás | A/B, dos no tomados, bucle `0..2` | `t04_saltos.asm` |
| `j` | hacia delante y hacia atrás | `t04_saltos.asm` |
| `jal`, `jr` con procedimiento no hoja y `$ra` en la pila | `suma(4)` recursiva | `t07_llamadas.asm` |
| `syscall` 11 y 10 | impresión de caracteres y terminación | `t05_tty.asm` (y todos) |
| `$zero`: escribir y comprobar que sigue 0 | escrituras con `add`, `addi`, `ori`, `lui`, `lw` | `t05_tty.asm` |

Además, `programs/` (material entregado, no cuenta como propio) también pasa
completo: `hello`, `array_sum`, `multiply`, `gcd`, `arithmetic`, `branches` y
`memory`.

# 8. Tests y limitaciones

## 8.1. Resultados de `run_tests.py`

Salida completa de `python3 tools/run_tests.py` (también en
`salida-tests.txt`):

```
Ejecutando 14 programas en la placa...
OK    programs/arithmetic.asm  (6315 ciclos)
OK    programs/array_sum.asm  (884 ciclos)
OK    programs/branches.asm  (920 ciclos)
OK    programs/gcd.asm  (2757 ciclos)
OK    programs/hello.asm  (283 ciclos)
OK    programs/memory.asm  (4814 ciclos)
OK    programs/multiply.asm  (1918 ciclos)
OK    tests/t01_aritmetica.asm  (3490 ciclos)
OK    tests/t02_logica.asm  (1605 ciclos)
OK    tests/t03_memoria.asm  (3217 ciclos)
OK    tests/t04_saltos.asm  (262 ciclos)
OK    tests/t05_tty.asm  (146 ciclos)
OK    tests/t06_desplaz.asm  (1920 ciclos)
OK    tests/t07_llamadas.asm  (550 ciclos)

14/14 correctos
```

Todos los programas se detienen con HALT y su TTY coincide exactamente con
MARS; no quedan nets en estado de error durante la ejecución.

## 8.2. Limitaciones y comportamientos conocidos

- **PC en instrucción ilegal.** El PC se incrementa en FETCH (PC+4) y la
  instrucción ilegal se detecta en DECODE; al pasar a HALT el PC queda en
  PC+4, aunque no se escriben registros ni memoria. Es una desviación de la
  lectura más estricta de R10 (“sin modificar ningún estado”) y se declara aquí.
- **PC tras `syscall` 10.** Por la misma razón, al detenerse el PC apunta a la
  instrucción siguiente. No se modifica nada más.
- **Reset de `$gp` y `$sp`.** El PC, la FSM y los registros del banco (salvo
  `$gp`/`$sp`) tienen borrado asíncrono con RESET. `$gp` y `$sp` cargan
  `0x1800`/`0x3FFC` en un flanco con RESET=1 (reset síncrono): hay que mantener
  el reloj activo mientras se pulsa Reset para que tomen su valor inicial.
- **Casos no definidos por la guía:** accesos a palabra no alineados, saltos a
  direcciones que no son múltiplo de 4, desbordamiento aritmético (la suma es
  módulo 2^32, sin excepciones) y accesos fuera de los 16 KiB (la memoria
  repite direcciones cada 16 KiB).
- **Servicios de `syscall`:** solo se implementan 10 y 11. Los servicios 1, 4
  y 5 de MARS no se implementan en hardware; los programas de prueba usan
  únicamente 10 y 11.
- **TTY:** 12 líneas de 48 caracteres; todos los tests caben.

# 9. Conclusión

La CPU multiciclo S-MIPS quedó implementada en `circuit/smips.circ` con los
seis subcircuitos obligatorios, sin VHDL, sin modificar `Board` ni `Memory` y
conservando los 10 pines y la apariencia de `CPU`. La FSM de 9 estados, la única
ALU y los registros internos permiten ejecutar las 23 instrucciones de S-MIPS
más `addu`/`addiu`, con `syscall` 10/11, memoria little-endian con cargas y
almacenamientos por byte y salida por TTY.

La comprobación final (`python3 tools/run_tests.py`, volcada en
`salida-tests.txt`) da **14/14 programas correctos**, con la salida del TTY
idéntica a MARS y sin nets en error. Los 7 programas de `tests/` cubren todas
las filas de la tabla de casos de la guía. La única desviación declarada es el
PC tras una instrucción ilegal o tras `syscall` 10, que queda en PC+4 porque el
PC se incrementa en FETCH; el resto del estado no se modifica.
