# t06_desplaz.asm
# Cubre: sll y srl con shamt = 0 y shamt distinto de 0; srl sobre un valor
#        negativo (entran ceros); sll sobre un negativo; jal/jr (hex8) y
#        syscall 11/10.
# Salida esperada:
#   00000005 00000050 00000005 0ffffff9 00000001
#   ffffff90
        .text
main:   addi $s0, $zero, 5
        addi $s1, $zero, -7
        sll  $a0, $s0, 0          # shamt = 0
        jal  hex8
        sll  $a0, $s0, 4          # shamt distinto de 0
        jal  hex8
        srl  $a0, $s0, 0          # shamt = 0
        jal  hex8
        srl  $a0, $s1, 4          # negativo: entran ceros
        jal  hex8
        srl  $a0, $s1, 31
        jal  hex8
        jal  nueva_linea
        sll  $a0, $s1, 4          # negativo desplazado a la izquierda
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
