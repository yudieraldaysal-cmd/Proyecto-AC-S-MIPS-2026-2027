# t01_aritmetica.asm
# Cubre: add y sub con operandos positivos y negativos; addi con inmediato
#        negativo; slt y slti con resultado 1 y 0, incluido un negativo en el
#        que la comparacion con signo y sin signo difiere; addiu y addu
#        mediante li y move. Tambien jal/jr (hex8) y syscall 11/10.
# Salida esperada:
#   000004e2 000003e1 000002ee fffffc11 00000001
#   00000000 00000001 00000000 fffffffd fffffffb
#   000003e8
        .text
main:   addi $s0, $zero, 1000
        addi $s1, $zero, 250
        addi $s2, $zero, -7
        add  $a0, $s0, $s1
        jal  hex8
        add  $a0, $s0, $s2
        jal  hex8
        sub  $a0, $s0, $s1
        jal  hex8
        sub  $a0, $s2, $s0
        jal  hex8
        slt  $a0, $s2, $s0
        jal  hex8
        jal  nueva_linea
        slt  $a0, $s0, $s2
        jal  hex8
        slti $a0, $s2, -6
        jal  hex8
        slti $a0, $s0, -1
        jal  hex8
        addi $a0, $zero, -3
        jal  hex8
        li   $a0, -5
        jal  hex8
        jal  nueva_linea
        move $a0, $s0
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
