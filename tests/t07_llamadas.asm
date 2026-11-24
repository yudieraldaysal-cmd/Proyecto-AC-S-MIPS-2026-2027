# t07_llamadas.asm
# Cubre: jal y jr con un procedimiento no hoja (suma recursiva) que guarda $ra
#        y el argumento en la pila y retorna correctamente; sw/lw con
#        desplazamiento; jal/jr (hex8) y syscall 11/10.
# Salida esperada:
#   0000000a
        .text
main:   addi $a0, $zero, 4
        jal  suma
        add  $a0, $v0, $zero
        jal  hex8
        jal  nueva_linea
        addi $v0, $zero, 10
        syscall

# suma(n) = n + suma(n-1), suma(0) = 0
suma:   addi $sp, $sp, -8
        sw   $ra, 4($sp)
        sw   $a0, 0($sp)
        bne  $a0, $zero, suma_rec
        add  $v0, $zero, $zero
        addi $sp, $sp, 8
        jr   $ra
suma_rec:
        addi $a0, $a0, -1
        jal  suma
        lw   $a0, 0($sp)
        lw   $ra, 4($sp)
        addi $sp, $sp, 8
        add  $v0, $v0, $a0
        jr   $ra

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
