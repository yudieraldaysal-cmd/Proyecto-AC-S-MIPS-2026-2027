# t04_saltos.asm
# Cubre: beq y bne tomados y no tomados; bucle hacia atras; j hacia delante y
#        hacia atras; jal/jr (letra y error) y syscall 11/10.
# Salida esperada: AB01201C
        .text
main:   addi $s0, $zero, 5
        addi $s1, $zero, 5
        addi $s2, $zero, 6
        beq  $s0, $s1, eq1        # beq tomado
        jal  error
eq1:    addi $a0, $zero, 65       # 'A'
        jal  letra
        beq  $s0, $s2, error      # beq no tomado
        bne  $s0, $s1, error      # bne no tomado
        bne  $s0, $s2, ne1        # bne tomado
        jal  error
ne1:    addi $a0, $zero, 66       # 'B'
        jal  letra
        add  $t0, $zero, $zero
loop:   add  $a0, $t0, 48         # '0'..'2'
        jal  letra
        addi $t0, $t0, 1
        slti $t1, $t0, 3
        bne  $t1, $zero, loop     # bucle hacia atras
        j    tras_loop            # j hacia delante
        jal  error
tras_loop:
        add  $t0, $zero, $zero
loopj:  add  $a0, $t0, 48         # '0'..'1'
        jal  letra
        addi $t0, $t0, 1
        slti $t1, $t0, 2
        beq  $t1, $zero, fin      # salida hacia delante
        j    loopj                # j hacia atras
fin:    addi $a0, $zero, 67       # 'C'
        jal  letra
        jal  nueva_linea
        addi $v0, $zero, 10
        syscall
error:  addi $a0, $zero, 33       # '!' si un salto se equivoca
        jal  letra
        addi $v0, $zero, 10
        syscall
letra:  addi $v0, $zero, 11
        syscall
        jr   $ra
nueva_linea:
        addi $a0, $zero, 10
        addi $v0, $zero, 11
        syscall
        jr   $ra
