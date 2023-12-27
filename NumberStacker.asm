data segment
     pozX db ?
     pozY db ?
     sirina dw ?
     visina dw ? 
     adresa dw ?
     boja db ?     
     trenutnaCifra db '1'         
     trenutnaX db 1          
     trenutnaY db 1
     testX db ?
     pocetnaX db 1
     smer db ?
     porukaParnost db 'Kraj igre, narusen uslov parnosti.Pritisnite bilo koji taster da igrate ponovo...$'
     porukaVrhKule db 'Kraj igre, dostignut vrh kule.Pritisnite bilo koji taster da igrate ponovo...$'
     trenutnaSekunda db ?
     ciljnaSekunda db ?   
    
data ends
; Deficijija stek segmenta
stek segment stack
     dw 128 dup(?)
stek ends

code segment
; Postavljanje pocetnih vrednosti promenljivih          
macro initGraph
     push ax
     mov ax, 0B800h
     mov es, ax
     mov pozX, 0
     mov pozY, 0
     mov sirina, 80
     mov visina, 25
     mov adresa, 0
     mov boja, 1         
     pop ax
endm
; Postavljanje tekuce pozicije na poziciju (x, y)               
macro setXY x y
     push ax
     push dx
     mov pozX, x
     mov pozY, y
     
     mov dx, sirina
     shl dx, 1
     mov ax, dx
     mov ah, pozY
     mul ah
     mov dl, pozX  
     shl dl, 1
     add ax, dx
   
     mov adresa, ax
     pop dx
     pop ax
endm
; Postavljanje tekuce boje
macro setColor b
     mov boja, b
endm
; Ispis stringa na ekran           
writeString macro str
    LOCAL petlja, krajParnost
    push ax
    push bx  
    push si
    mov si, 0
    mov ah, boja
    mov bx, adresa
petlja:
    mov al, str[si]
    cmp al, '$'
    je krajParnost
    mov es:[bx], al   
    mov es:[bx+1], ah
    add bx, 2
    add si, 1
    jmp petlja
krajParnost:           

    mov ax, si
    add al, pozX
    mov ah, pozY
    setXY al ah
    pop si
    pop bx
    pop ax
endm
; Ucitavanje znaka bez prikaza i memorisanja
keyPress macro
    push ax
    mov ah, 08
    int 21h
    pop ax
endm  
; Ucitavanje znaka bez prikaza
readkey macro c
    push ax
    mov ah, 08
    int 21h
    mov c, al
    pop ax 
endm
; Ispis znaka na tekucu poziciju
macro Write c
     push bx        
     push dx
     mov bx, adresa
     mov es:[bx], c
     mov dl, boja
     mov es:[bx+1], dl
     pop dx
     pop bx
endm
; krajParnost programa
krajPrograma macro
    mov ax, 4c02h
    int 21h
endm        
; Brisanje ekrana     
macro clrScreen
   LOCAL petlja
   push bx
   push cx
   mov bx, 0
   mov cx, 2000
petlja:
   mov es:[bx], ' '
   mov es:[bx+1], 7  
   add bx, 2
   loop petlja
   pop cx
   pop bx
endm 
  
start:
     ; postavljanje segmentnih registara
    assume cs:code, ss:stek
    mov ax, data
    mov ds, ax
     ; inicijalizacija grafike  
    initGraph
        
    mov al, trenutnaX     
    mov ah, trenutnaY
    setXY al ah ; Postavi XY koordinate   
    mov al, trenutnaCifra ; Pomeri vrednost trenutnaCifra u registar al 
    write al ; Ispisi vrednost iz registra al
           
     
    mov ah, 2Ch ; Pomeri vrednost 2Ch u registar ah      
    int 21h ; Pozovi prekid 21h za dobijanje trenutnog sistemskog vremena
    mov [trenutnaSekunda], dh ; Pomeri vrednost DH (trenutna sekunda) u memorijsku lokaciju trenutnaSekunda  
    mov al, 5 ; Pomeri vrednost 5 u registar al      
    add al, [trenutnaSekunda] ; Dodaj vrednost trenutnaSekunda iz memorijske lokacije u registru al  
    mov [ciljnaSekunda], al ; Pomeri vrednost iz registra al u memorijsku lokaciju ciljnaSekunda  
       
    mov cx, 100 ; Podesi brojac CX na vrednost 50      
petlja:    
    mov ah, 2Ch ; Pomeri vrednost 2Ch u registar ah      
    int 21h ; Pozovi prekid 21h za dobijanje trenutnog sistemskog vremena
    mov al, dh ; Pomeri vrednost DH (trenutna sekunda) u registar al       
    
    cmp [ciljnaSekunda], 60 ; Uporedi vrednost iz memorijske lokacije ciljnaSekunda sa 60
    jnb resetTargetTime ; Skoci na oznaku resetTargetTime ako je uslov "not below" (nije ispod) ispunjen odnosno ciljnaSekunda >= 60
    
    cmp al, [ciljnaSekunda] ; Uporedi vrednost iz registra al sa vrednošcu iz memorijske lokacije
    jb nastavi ; Skoci na oznaku nastavi ako je uslov "below" (ispod) ispunjen, odnosno ako nije proslo 5 sekundi
  
    mov al, trenutnaX
    mov ah, trenutnaY
    inc ah ; Povecaj vrednost u registru ah(trenutnaY) za 1 
    ;Provera da li smo trenutno na "dnu", odnosno da li bi nova pozicija bila na 6. nivou(ima 5 dozvoljenih)
    cmp ah, 6 ; Uporedi vrednost u registru ah sa 6
    je generisiBroj ; Skoci na oznaku generisiBroj ako je uslov "equal" (jednako) ispunjen, odnonso ako bi novi nivo bio ispod dna  
    
    setXY al,ah ; Postavi XY koordinate da bi dobili offset adresu ispod
    mov bx, adresa ; Pomeri offset adresu u registar BX
    mov al, es:[bx+1]   ; Pomeri vrednost iz memorijske lokacije es:[bx+1] i.e. boju u registar al 
    cmp al, 1 ;Proveram da li je pozicija ispod trenutne "obojena"
    jne propadanje ; Skoci na oznaku propadanje ako je uslov "not equal" (nije jednako) ispunjen, odnonso ako je pozicija ispod prazna    
    
    mov al, es:[bx] ; Pomeri vrednost iz memorijske lokacije es:[bx], i.e. karakter u registar al
    cmp al, ' ' ; Uporedi vrednost u registru al sa razmakom (' '), odnosno da li je polje isopd prebrisano.
    je propadanje ; Skoci na oznaku propadanje ako je uslov "equal" (jednako) ispunjen, odnosno ispod je prazno
    
    ;Inace ispod imamo broj,
    cmp ah, 2 ;ako imamo broj ispod na 2. nivou, onda se nalazimo na vrhu kule i skacemo na krajVrhKule igre
    je krajVrhKule
    
    ;provera parnosti  
    mov ah, trenutnaCifra ; Pomeri vrednost trenutnaCifra u registar ah
    and ah, 1 ; Izvrsi logicko "i" izmedu ah i 1 kako bi se dobila parnost trenutnog broja
    and al, 1 ; Izvrsi logicko "i" izmedu ah i 1 kako bi se dobila parnost broja ispod
    cmp ah, al ; uporedi parnosti
    jne krajParnost  ; Skoci na oznaku krajParnost ako je uslov "not equal" (nije jednako) ispunjen, jer ne mozemo da slazemo brojeve razlicite parnosti
    jmp generisiBroj ; inace skoci na oznaku generisiBroj
   
propadanje:    
    ; Obrisi karakter sa trenutne pozicij
    mov al, trenutnaX
    mov ah, trenutnaY
    setXY al ah
    mov al, ' '
    write al
    
    add trenutnaY, 1 ; Povecaj vrednost trenutnaY za 1
    mov al, trenutnaX
    mov ah, trenutnaY   
    setXY al, ah ;Postavi nove kordinate
    mov al, trenutnaCifra
    write al ; ispisi trenutnu cifru

    ;Azuriraj vreme
    mov ah, 2Ch ; Nabavi trenutno vreme iz sistema
    int 21h
    mov [trenutnaSekunda], dh
    ; Ažuriraj ciljno vreme za naredni interval
    mov al, [trenutnaSekunda] ; Vrati trenutno vreme iz memorije
    add al, 5 ; Izracunaj novu ciljnu sekundu
    mov [ciljnaSekunda], al ; Sacuvaj ciljnu sekundu u memorijiy
       
    jmp petlja 
    
resetTargetTime:
    sub [ciljnaSekunda], 60 ; Oduzmi 60 od ciljne sekunde
    jmp nastavi
    
generisiBroj:

    sub cx, 1 ; Smanji vrednost brojaca CX za 1
    cmp cx, 0
    je krajParnost    
    
    inc trenutnaCifra ; Povecaj vrednost trenutnaCifra za 1
    cmp trenutnaCifra, ":" ; Poredimo sa : zato sto u ASCII kodu : ide posle 9
    je resetujCifru
    
    inc pocetnaX ; Povecaj vrednost pocetnaX za 1
    cmp pocetnaX, 10
    je resetujPocetnu ; Resetuj ako dode do 10
    
    ;azuriramo sve promenljive
    mov al, pocetnaX
    mov trenutnaX, al
    mov trenutnaY, 1
    setXY al 1
    mov al, trenutnaCifra
    write al ;generisemo novi broj          
    jmp petlja

resetujCifru:

    mov trenutnaCifra, '0' ; Postavi vrednost '0' u trenutnaCifra, zato sto ce se u sledecoj iteraciji podici na 1
    jmp generisiBroj 
    
resetujPocetnu:

    mov pocetnaX, 0 ; Postavi vrednost 0 u pocetnaX, zato sto ce se u sledecoj iteraciji podici na 1
    jmp generisiBroj
       
nastavi:
    ; Proveri da li je pritisnuta neki taster
    mov ah, 1        ; Pomeri vrednost 1 u registar ah 
    int 16h          ; Pozovi prekid 21h za proveru da li je taster pritisnut
    jnz pritisnutTaster   ; Skoci na pritisnutTaster ako je uslov  "jump if not zero." (nije 0) zadovoljen, odnosno ako je pritisnut taster
    
    ;Inace nastavi sa iterisanjem u glavnoj petlji
    jmp petlja
  
pritisnutTaster:   
      
       readKey smer
       cmp smer, 'a'
       je levo
       cmp smer, 'd'
       je desno
       jmp krajParnost            
       
       levo:
       mov al, trenutnaX
       sub al, 1 ; Da proverimo da li mozemo levo, smanjujemo X za 1
       cmp al, 1 ;Poredi novu poziciju sa levom granicom ekrana 1
       jl petlja ; Skoci na petlja ako je uslov  "jump if less." (manje) zadovoljen, odnosno ako ne mozemo da se pomerimo
       ;Moze levo
       mov testX, al
       jmp dalje
       
       desno:
       mov al, trenutnaX
       add al, 1 ; Da proverimo da li mozemo desno, povecavamo X za 1
       cmp al, 10 ;Poredi novu poziciju sa desnom granicom ekrana 1
       jg petlja ; Skoci na petlja ako je uslov  "jump if greater." (vece) zadovoljen, odnosno ako ne mozemo da se pomerimo desno
       ;Moze desno
       mov testX, al
       jmp dalje
    
       ;Provera da li smo se sudarili s postojecim brojem 
dalje:            
       mov al, testX    
       mov ah, trenutnaY
       setXY al ah       ; Postavi XY koordinate da bi dobili offset adresu ispod
       mov bx, adresa    ; Pomeri offset adresu u registar BX  
       mov al, es:[bx+1] ; Pomeri vrednost iz memorijske lokacije es:[bx+1] i.e. boju u registar al  
       cmp al, 1 ;Proveram da li je pozicija ispod trenutne "obojena"
       je proveriPrazno ; Skoci na oznaku proveriPrazno ako je uslov "equal" (jednako) ispunjen, odnonso ako je pozicija ispod obojena
       jmp pomeranje ; Inace skoci na pomeranje
       
proveriPrazno:      
       mov al, es:[bx]   ; Pomeri vrednost iz memorijske lokacije es:[bx] i.e. karakter u registar al
       cmp al, ' ';Proveram da li je pozicija ispod trenutne "prebrisana"
       je pomeranje  ; Skoci na oznaku pomeranje ako je uslov "not equal" (nije jednako) ispunjen, odnonso ako je pozicija ispod prebrisana    
       jmp petlja ;Inace ne mozemo da se pomeramo pa nastavi petlju 
       
              
pomeranje:
       mov al, trenutnaX
       mov ah, trenutnaY
       setXY al ah
       mov al, ' '  ;Obrisi karakter na trenutnoj poziciji
       write al    
       
       mov al, testX             
       mov trenutnaX, al ;azuriraj trenutno X
       setXY al, ah
       mov al, trenutnaCifra  ;Napisi trenutnu cifru na novu poziciju
       write al
       jmp petlja
            
       
       
krajParnost:
     ; krajParnost programa
     setXY 1 23
     setColor 14
     writeString porukaParnost
     keyPress
     krajPrograma
     
krajVrhKule:
     ; krajVrhKule programa
     setXY 1 23
     setColor 14
     writeString porukaVrhKule
     keyPress
     krajPrograma
code ends
end start