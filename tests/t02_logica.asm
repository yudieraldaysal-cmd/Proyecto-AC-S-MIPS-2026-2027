# t02_logica.asm
# Cubre: and y or con operandos que tienen unos en los 16 bits altos; andi y
#        ori con inmediato cuyo bit 15 vale 1 (extension con ceros); lui con
#        el bit 15 en 1. Tambien jal/jr (hex8) y syscall 11/10.
# Salida esperada:
#   0f0f000f fffff0ff 00008000 00008000 80010000
        .text
main:   addi $s0, $zero, -1       # 0xffffffff
        lui  $s1, 0xffff
        ori  $s1, $s1, 0x00ff     # 0xffff00ff
        lui  $s2, 0x0f0f
        ori  $s2, $s2, 0xf00f     # 0x0f0ff00f
        and  $a0, $s1, $s2
        jal  hex8
        or   $a0, $s1, $s2
        jal  hex8
        andi $a0, $s0, 0x8000     # 0x00008000, no 0xffff8000
        jal  hex8
        ori  $a0, $zero, 0x8000   # 0x00008000
        jal  hex8
        lui  $a0, 0x8001          # 0x80010000
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
