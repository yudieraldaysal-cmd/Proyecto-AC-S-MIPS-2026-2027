# t03_memoria.asm
# Cubre: lw y sw con desplazamiento 0, positivo y negativo; lb y lbu sobre
#        bytes con el bit 7 en 1 en las posiciones 3 y 2 de la palabra; sb en
#        los cuatro carriles de una palabra, comprobando con lw que los otros
#        bytes no cambian; la, jal/jr (hex8) y syscall 11/10.
# Salida esperada:
#   80e97f11 ffffff80 00000080 ffffffe9 000000e9
#   ddccbbaa 12345678 12ff5678 12ff5678 12345678
        .data
palabra: .word 0x80e97f11
destino: .space 8
        .text
main:   la   $s0, palabra
        la   $s1, destino
        lw   $a0, 0($s0)
        jal  hex8
        lb   $a0, 3($s0)          # byte 0x80 con signo
        jal  hex8
        lbu  $a0, 3($s0)          # byte 0x80 sin signo
        jal  hex8
        lb   $a0, 2($s0)          # byte 0xe9 con signo
        jal  hex8
        lbu  $a0, 2($s0)          # byte 0xe9 sin signo
        jal  hex8
        jal  nueva_linea
        addi $t0, $zero, 0xaa
        sb   $t0, 0($s1)
        addi $t0, $zero, 0xbb
        sb   $t0, 1($s1)
        addi $t0, $zero, 0xcc
        sb   $t0, 2($s1)
        addi $t0, $zero, 0xdd
        sb   $t0, 3($s1)
        lw   $a0, 0($s1)          # ddccbbaa
        jal  hex8
        lui  $t2, 0x1234
        ori  $t2, $t2, 0x5678
        sw   $t2, 4($s1)          # sw con desplazamiento positivo
        lw   $a0, 4($s1)          # 12345678
        jal  hex8
        addi $t1, $zero, -1
        sb   $t1, 6($s1)          # cambia solo el byte 2 de la palabra +4
        lw   $a0, 4($s1)          # 12ff5678
        jal  hex8
        addi $s2, $s1, 8
        lw   $a0, -4($s2)         # lw con desplazamiento negativo
        jal  hex8
        sw   $t2, -4($s2)         # sw con desplazamiento negativo
        lw   $a0, -4($s2)         # vuelve a 12345678
        jal  hex8
        jal  nueva_linea
        addi $v0, $zero, 10
        syscall

# imprime $a0 como 8 digitos hex y un espacio
hex8:   add  $t0, $a0, $zero
        addi $t1, $zero, 8
h8_bucle:
        srl  $t2, $t0, 28
        slti $t3, $t2, 10
        beq  $t3, $zero, h8_letra
        addi $a0, $t2, 48
        j    h8_sal
h8_letra:
        addi $a0, $t2, 87
h8_sal: addi $v0, $zero, 11
        syscall
        sll  $t0, $t0, 4
        addi $t1, $t1, -1
        bne  $t1, $zero, h8_bucle
        addi $a0, $zero, 32
        addi $v0, $zero, 11
        syscall
        jr   $ra

nueva_linea:
        addi $a0, $zero, 10
        addi $v0, $zero, 11
        syscall
        jr   $ra
