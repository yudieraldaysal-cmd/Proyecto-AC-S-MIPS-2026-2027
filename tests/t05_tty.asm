# t05_tty.asm
# Cubre: lbu, beq y j para recorrer una cadena; syscall 11 y 10; escrituras en
#        $zero con add, addi, ori, lui y lw, comprobando que $zero sigue 0.
# Salida esperada: OK0
        .data
msg:    .asciiz "OK"
        .text
main:   la   $s0, msg
bucle:  lbu  $a0, 0($s0)
        beq  $a0, $zero, fin
        jal  letra
        addi $s0, $s0, 1
        j    bucle
fin:    add  $s1, $zero, $zero
        add  $zero, $s1, $s1      # escribir $zero con add
        addi $zero, $zero, 7      # escribir $zero con addi
        ori  $zero, $zero, 0xffff # escribir $zero con ori
        lui  $zero, 0x1234        # escribir $zero con lui
        la   $s1, msg
        lw   $zero, 0($s1)        # escribir $zero con lw
        add  $a0, $zero, $zero    # $zero debe seguir valiendo 0
        addi $a0, $a0, 48         # '0'
        jal  letra
        jal  nueva_linea
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
