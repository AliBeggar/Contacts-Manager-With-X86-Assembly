; ===================================================================
; CONTACT MANAGEMENT SYSTEM
; ===================================================================

data segment                          
    ;--------------------------- MENU --------------------------
    ; Menu display strings
    menu        db "----------------MENU----------------",13,10,"$"
    menu_options db '1. ADD A CONTACT',13,10
                db '2. VIEW ALL CONTACTS',13,10
                db '3. SEARCH A CONTACT',13,10
                db '4. MODIFY A CONTACT',13,10
                db '5. DELETE A CONTACT',13,10  
                db '6. Display all contacts whose name starts with a given prefix',13,10 
                db '7. Display all contacts whose phone number contains the given part',13,10  
                db '8. EXIT',13,10
                db '------------------------------------',13,10
                db 'Enter a choice : $'   
    
    ;--------------------------- DATA --------------------------
    array       db 352 dup(?)    ; Array to store contacts (16 contacts * (10 bytes of name + 10 bytes of phone number + 2 for the '$'))
    empty_array dw -1   
    choice      db 2,?,2 dup (' ')
    enter       db 2,?,2 dup(' ')   ; Buffer for enter key/confirmation inputs
    buffer      db 11,?,11 dup(' ') ; Input buffer for names and phone numbers
    count       dw 0,'$'         ; Counter for number of contacts stored     
    sort        db 11 dup('$')  ; A varibale used for sorting  
    min         dw ?  ; Another varibale used for sorting    
    phone_number_part db 352 dup(?)
    prefix_count dw 0
    
    ;------------------------- MESSAGES -----------------------
    ; Messages
    msg1        db 'Enter the name: $'
    msg2        db 'Enter the phone number: $'
    msg3        db 'CONTACTS : $'
    msg4        db '===== NAME ========= PHONE =====$'   
    msg5        db 'Contact added successfully!$'                 
    msg6        db 'Enter the name that you are looking for: $'
    msg7        db 'Contact found! The phone number is : $'   
    msg8        db 'What is the name of the contact that you want to modify? $'  
    msg9        db 'Do you want to modify this contact? (y/n): $'
    msg10       db 'New name: $'
    msg11       db 'New phone number: $'   
    msg12       db 'Contact has been modified successfully!$'      
    msg13       db 'What is the name of the contact that you want to delete? $'     
    msg14       db 'Do you want to delete this contact? (y/n): $'
    msg15       db 'Contact successfully deleted!$'       
    msg16       db 'Give the prefix: $'   
    msg17       db 'Give a part of the phone number: $'
    
    ;-------------------------- ERRORS ------------------------  
    ; Error messages
    error1      db 'Invalid phone number!$'   
    error2      db 'Contacts list is full!$' 
    error3      db 'Invalid choice!$'      
    error4      db 'Contact list empty!$' 
    error5      db 'Contact not found!$' 
    error6      db 'Name cannot be empty. $'
    pkey        db "press any key...$"
ends

stack segment
    dw   128  dup(0)    ; Define stack segment with 128 words
ends

code segment
start:
    ; Set segment registers
    mov ax, data
    mov ds, ax
    mov es, ax

    ; ================== MACRO DEFINITIONS ===================
    
    ; Macro to print a string
    print MACRO text   
        push ax
        lea dx, text
        mov ah, 09h
        int 21h    
        pop ax  
    ENDM 
    
    ; Macro to print a string with newline before it
    println MACRO text
        newline    
        push ax
        lea dx, text
        mov ah, 09h
        int 21h
        pop ax 
    ENDM
    
    ; Macro to read a string from user input
    sscanf MACRO str 
        push ax
        push dx 
        push bx
        mov dx, offset str
        mov ah, 0ah
        int 21h   
        xor bx, bx
        mov bl, buffer[1]
        mov buffer[bx+2], '$'    ; Add string terminator
        pop bx
        pop dx
        pop ax   
    ENDM   
    
    ; Macro to print a newline
    newline MACRO
        push ax
        push dx
        mov ah, 02h 
        mov dl, 0Dh     ; Carriage return
        int 21h
        mov dl, 0Ah     ; Line feed
        int 21h
        pop dx
        pop ax
    ENDM 
    
    ; Macro to copy string from source to destination
    strcpy MACRO src, dest
        push cx     
        push si  
        push di 
        lea di, dest
        lea si, src + 2
        mov cx, 11       ; Copy 11 bytes (name or phone number)
        rep movsb
        pop di
        pop si
        pop cx
    ENDM 
    
    ; Macro to clear a buffer
    clrbuff MACRO text
        push cx
        push di
        push ax 
        mov [text+1], 0   
        lea di, text+2
        mov cx, 11                 
        mov al, ' '
        rep stosb             
        pop ax
        pop di
        pop cx
    ENDM
    
    ; ====================== MAIN MENU ======================
    recall_menu:
        call clrscr    ; Clear screen and display menu
        println menu
        print menu_options
    
    ; ====================== CHOICE HANDLING ======================
    ; Read user choice and branch to appropriate section
    sscanf choice
    cmp [choice + 2], '1' 
    je choice1          ; Jump to add contact
    cmp [choice + 2], '2'
    je choice2          ; Jump to view contacts
    cmp [choice + 2], '3' 
    je choice3          ; Jump to search contact
    cmp [choice + 2], '4' 
    je choice4          ; Jump to modify contact
    cmp [choice + 2], '5'  
    je choice5          ; Jump to delete contact 
    cmp [choice + 2], '6'
    je choice6
    cmp [choice + 2], '7'
    je choice7     
    cmp [choice + 2], '8' 
    je choice8          ; Jump to exit program
    
    ; Invalid choice handling
    call clrscr
    print error3
    sscanf enter
    jmp recall_menu
    
    ; ====================== ADD CONTACT ======================
    choice1: 
        call clrscr   
        mov ax, [count]
        cmp ax, 16           ; Check if contacts list is full (max 16 contacts)
        jge contacts_full
        
        ; Get contact name
    cannot_be_empty1:
        print msg1
        sscanf buffer
        mov al, [buffer+1]
        cmp al, 0            ; Check if name is empty
        je cannot_be_empty   
        
        ; Calculate position to store in array
        mov ax, [count]
        mov bx, 22           ; Each contact takes 22 bytes (11 for name, 11 for number)
        mul bx
        mov bx, ax 
        strcpy buffer, array+bx    ; Copy name to array
        
        ; Get phone number
    re_read_pn: 
        newline 
        print msg2  
        sscanf buffer
        mov al, 10  
        cmp al, [buffer+1]       ; Check if phone number has exactly 10 digits
        jne invalidpn   
        
        ; Validate that all characters are digits (0-9)
        lea si, buffer + 2   
        push si
        mov cx, 10
    cmphigh:                ; Check if any digit > '9'
        mov al, [si]    
        cmp al, '9' 
        jg invalidpn
        inc si
        loop cmphigh   
        
        pop si
        mov cx, 10 
    cmplow:                 ; Check if any digit < '0'  
        mov al, [si]      
        cmp al, '0' 
        jl invalidpn
        inc si
        loop cmplow
        
        ; Store phone number in array
        add bx, 11           ; Move to phone number position after name
        strcpy buffer, array+bx
        clrbuff buffer  
        inc count           ; Increment contact count  
        inc bx
        lea si, array+bx
        inc si
        mov empty_array, si
        ; Contact added
        println msg5
        sscanf enter
        jmp recall_menu
        
        ; Phone number validation error handling
    invalidpn: 
        println error1
        jmp re_read_pn 
        
        ; Empty name error handling
    cannot_be_empty: 
        println error6   
        newline
        jmp cannot_be_empty1
        
        ; Full contacts list error handling
    contacts_full:
        print error2
        jmp recall_menu 
    
    ; ====================== VIEW CONTACTS ======================
    choice2:
        call clrscr
        print msg3
        ; Display contact count 
        mov bx,[count]
        cmp bx,10
        jge plus_ten 
        push [count]
        add [count], 48      ; Convert count to character
        print count   
        newline
        pop count   
        
        ; Check if list is empty
        cmp [count], 0
        je emptylist
        
        ; Display all contacts 
    display:
        println msg4  
        lea si, array 
        mov cx, [count]
    viewloop: 
        push cx 
        inc dh
        push dx
        mov dl, 05h
        mov ah, 02h
        int 10h 
        print si            ; Print name
        add si, 11  
        mov ah, 03h
        int 10h
        mov dl, 18 
        mov ah, 02h
        mov bh, 0
        int 10h
        print si            ; Print phone number
        add si, 11
        pop dx
        pop cx
        loop viewloop  
        
        sscanf enter
        jmp recall_menu  
        
        ; Empty list error handling
    emptylist: 
        print error4
        sscanf enter
        jmp recall_menu 
        ; More than 10 contacts
    plus_ten:
        push [count]
        sub [count], 10
        add [count], 48      ; Convert count to character
        mov ax, 49
        xchg ax,[count] 
        mov byte ptr [count+1], al
        print count
        newline
        pop count
        jmp display
    ; ====================== SEARCH CONTACT ======================   
    choice3:
        call clrscr   
        
        ; Check if list is empty
        mov ax, [count]
        cmp ax, 0
        je search_empty
        
        ; Get name to search
        print msg6
        sscanf buffer
        
        ; Search through contacts
        lea si, array
        lea di, buffer+2 
        mov cx, [count]
    search_loop:
        push di    
        push si
        push cx
        mov cx, 10
        repe cmpsb          ; Compare strings until equal or 10 bytes
        je contact_found
        pop cx
        pop si 
        pop di
        add si, 22           ; Move to next contact
        loop search_loop
        
        ; Contact not found
        clrbuff buffer  
        println error5 
        jmp recall_menu
        
        ; Contact found - display phone number
    contact_found: 
        clrbuff buffer
        println msg7
        pop cx
        pop si
        add si, 11           ; Move to phone number position
        print si
        sscanf enter
        jmp recall_menu   
        
        ; Empty list error handling
    search_empty: 
        print error4  
        sscanf enter
        jmp recall_menu
    
    ; ====================== MODIFY CONTACT ======================
    choice4:
        call clrscr  
        
        ; Check if list is empty
        mov ax, [count]
        cmp ax, 0
        je modify_empty
        
        ; Get name to modify
        print msg8
        sscanf buffer
        
        ; Search for contact to modify
        lea si, array
        lea di, buffer+2 
        mov cx, [count]
    modify_search_loop:
        push di    
        push si
        push cx
        mov cx, 10
        repe cmpsb          ; Compare strings
        je modify_contact_found
        pop cx
        pop si 
        pop di
        add si, 22           ; Move to next contact
        loop modify_search_loop
        
        ; Contact not found
        clrbuff buffer  
        println error5 
        jmp recall_menu
        
        ; Contact found - confirm modification
    modify_contact_found: 
        clrbuff buffer
        println msg7
        pop cx
        pop si
        add si, 11           ; Display phone number
        print si
        println msg9
        sscanf enter
        mov al, [enter+2]
        cmp al, 'y'         ; Check for confirmation
        je modify
        jmp recall_menu
        
        ; Modify contact
    modify: 
        sub si, 11   ; Move back to name position
        
        ; Get new name
    modify_cannot_be_empty1:
        newline
        print msg10
        sscanf buffer 
        mov al, [buffer+1]
        cmp al, 0            ; Check if name is empty
        je modify_cannot_be_empty
        strcpy buffer, si
        add si, 11           ; Move to phone number position
        
        ; Get new phone number
    modify_re_read_pn: 
        clrbuff buffer
        newline
        print msg11
        sscanf buffer
        push si
        
        ; Validate phone number
        mov al, 10
        cmp al, [buffer+1]  ; Check for 10 digits
        jne modify_invalidpn
        lea si, buffer + 2
        push si
        mov cx, 10
    modify_cmphigh:         ; Check if any digit > '9'
        mov al, [si]
        cmp al, '9' 
        jg modify_invalidpn
        inc si
        loop modify_cmphigh
        
        pop si
        mov cx, 10
    modify_cmplow:          ; Check if any digit < '0'
        mov al, [si]
        cmp al, '0' 
        jl modify_invalidpn
        inc si
        loop modify_cmplow
        
        ; Save new phone number
        pop si
        strcpy buffer, si
        clrbuff buffer  
        newline
        print msg12         ; Success message
        sscanf enter
        jmp recall_menu
        
        ; Phone number validation error handling
    modify_invalidpn: 
        newline
        print error1
        jmp modify_re_read_pn 
        
        ; Empty name error handling
    modify_cannot_be_empty: 
        println error6 
        jmp modify_cannot_be_empty1    
        
        ; Empty list error handling
    modify_empty: 
        print error4 
        sscanf enter
        jmp recall_menu
    
    ; ====================== DELETE CONTACT ======================
    choice5:
        call clrscr 
        
        ; Check if list is empty
        mov ax, [count]
        cmp ax, 0
        je delete_empty
        
        ; Get name to delete
        print msg13
        sscanf buffer
        
        ; Search for contact to delete
        lea si, array
        lea di, buffer+2 
        mov cx, [count] 
        xor bx, bx
    delete_search_loop:
        push di    
        push si
        push cx
        mov cx, 10 
        inc bx              ; Keep track of position
        repe cmpsb          ; Compare strings
        je delete_contact_found
        pop cx
        pop si 
        pop di
        add si, 22           ; Move to next contact
        loop delete_search_loop
        
        ; Contact not found
        clrbuff buffer  
        println error5 
        jmp recall_menu
        
        ; Contact found - confirm deletion
    delete_contact_found:
        pop cx
        pop si
        clrbuff buffer 
        println msg7 
        add si, 11           ; Display phone number
        print si
        sub si, 11
        println msg14
        sscanf enter
        mov al, [enter+2]
        cmp al, 'y'         ; Check for confirmation
        je delete
        jmp recall_menu
        
        ; Delete contact and shift array elements
    delete:
        mov ax, 22
        sub bx, [count]
        neg bx
        mul bx 
        cmp ax, 0
        jne not_zero
        inc ax
    not_zero: 
        mov cx, ax 
        lea di, si          ; Destination is current contact
        lea si, si+22       ; Source is next contact
        rep movsb           ; Shift everything up
        dec count           ; Decrement contact count
        
        ; Clear last entry
        mov ax, 22
        mul [count] 
        mov bx, ax
        mov cx, 21
    for_fill:    
        mov array+bx, ' '
        inc bx
        loop for_fill 
        
        println msg15       ; Success message
        sscanf enter
        jmp recall_menu  
        
        ; Empty list error handling
    delete_empty: 
        print error4  
        sscanf enter
        jmp recall_menu  
                                      
      ; ====================== NAME PREFIX ======================       
        choice6:
        call clrscr   
        
        ; Check if list is empty
        mov ax, [count]
        cmp ax, 0
        je name_prefix_search_empty
        
        ; Get name prefix to search
        print msg16 
        clrbuff buffer
        sscanf buffer
        ;display
        println msg4
        ; Search through contacts 
        mov prefix_count,0
        lea si, array
        mov cx, [count]
    name_prefix_search_loop:
        continue_name_prefix_search: push cx
        lea di, buffer+2 
        mov cl, [buffer+1]
        xor ch,ch 
        push si
        repe cmpsb          ; Compare strings
        pop si
        je name_prefix_found  
        pop cx 
        add si, 22
        loop name_prefix_search_loop
        cmp [prefix_count], 0
        jne name_prefix_search_end
        ; Contact not found
        clrbuff buffer  
        println error5 
        jmp recall_menu
        
        ; Contact found - display phone number
    name_prefix_found:  
        inc dh
        push dx  
        mov dl, 05h
        mov ah, 02h
        int 10h 
        print si            ; Print name
        add si, 11  
        mov ah, 03h
        int 10h
        mov dl, 18 
        mov ah, 02h
        mov bh, 0
        int 10h
        print si            ; Print phone number
        pop dx
        inc prefix_count 
        pop cx          
        add si,11 
        jmp continue_name_prefix_search  
        ;display
        name_prefix_search_end:
        sscanf enter   
        mov prefix_count, 0
        jmp recall_menu   
        
        ; Empty list error handling
    name_prefix_search_empty: 
        print error4  
        sscanf enter
        jmp recall_menu
    ; ====================== PHONE NUMBER PART ======================          
    choice7:
     call clrscr   
        
        ; Check if list is empty
        mov ax, [count]
        cmp ax, 0
        je phone_part_search_empty
        
        ; Get phone part to search
        print msg17 
        clrbuff buffer
        sscanf buffer
        ;display
        println msg4
        ; Search through contacts 
        mov prefix_count,0
        lea si, array+11
        mov cx, [count]
    phone_part_search_loop:
        continue_phone_part_search: 
        push cx
        push si 
        mov bx, si
        mov cx,10
        phone_part_search:
            lea di, buffer+2   
            push cx
            push si
            lea di, buffer+2
            mov cl, [buffer+1]
            xor ch,ch 
            repe cmpsb          ; Compare strings 
            je phone_part_found    
            pop si
            pop cx
            inc si
            ;cmp [si + buffer + 1 ],'$'          
        loop phone_part_search
        pop si
        pop cx 
        add si, 22
        loop phone_part_search_loop
        cmp [prefix_count], 0
        jne phone_part_search_end
        ; Contact not found
        clrbuff buffer  
        println error5 
        jmp recall_menu
        
        ; Contact found - display phone number
    phone_part_found:
        mov si,bx  
        inc dh
        push dx  
        mov dl, 05h
        mov ah, 02h
        int 10h  
        sub si , 11
        print si           ; Print name
        add si, 11  
        mov ah, 03h
        int 10h
        mov dl, 18 
        mov ah, 02h
        mov bh, 0
        int 10h
        print si            ; Print phone number
        pop dx
        inc prefix_count
        pop si 
        pop cx 
        pop si 
        pop cx          
        add si,22
        jmp continue_phone_part_search  
        ;display
        phone_part_search_end:
        sscanf enter   
        mov prefix_count, 0
        jmp recall_menu   
        
        ; Empty list error handling
    phone_part_search_empty: 
        print error4  
        sscanf enter
        jmp recall_menu
    
    ; ====================== EXIT PROGRAM ======================
    choice8: 
        println pkey   
        mov ah, 1
        int 21h
        mov ax, 4c00h       ; DOS terminate program function
        int 21h  
    
    ; ====================== PROCEDURES ======================
    ; Procedure to clear the screen
    proc clrscr 
        push ax
        push bx
        push cx
        push dx  
        mov ax, 0600h   ; Scroll entire page
        mov bh, 07h     ; Normal attribute (white on black)
        mov cx, 0000h   ; Upper left corner
        mov dx, 184Fh   ; Lower right corner
        int 10h
        mov ah, 02h     ; Set cursor position
        mov bh, 00h     ; Page number
        mov dx, 0000h   ; Row 0, column 0
        int 10h  
        pop dx
        pop cx
        pop bx
        pop ax
        ret 
    endp
    
    ; Procedure to clear buffer
    proc clrbuff
        push cx
        push di
        push ax
        mov [buffer], 11    
        mov [buffer+1], 0   
        lea di, [buffer+2]
        mov cx, 11                 
        mov al, ' '
        rep stosb             
        pop ax
        pop di
        pop cx
    endp 
ends

end start ; set entry point and stop the assembler.