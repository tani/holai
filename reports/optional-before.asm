DEFUNC EXPANSION

(PROGN
 (DECLAIM (FTYPE (FUNCTION (&REST T) *) INSPECT-ADD))
 (SETF (FDEFINITION 'INSPECT-ADD)
         (LABELS ((INSPECT-ADD (&REST #:ARGUMENTS132)
                    (IF (< (LENGTH #:ARGUMENTS132) 3)
                        (APPLY #'HOL2CL.RUNTIME:PARTIAL #'INSPECT-ADD
                               #:ARGUMENTS132)
                        (LET* ((#:TAIL133 #:ARGUMENTS132)
                               (A (POP #:TAIL133))
                               (B (POP #:TAIL133))
                               (C (POP #:TAIL133))
                               (#:RESULT134 (PROGN (+ A B C))))
                          (IF #:TAIL133
                              (IF (FUNCTIONP #:RESULT134)
                                  (APPLY #:RESULT134 #:TAIL133)
                                  (ERROR 'TYPE-ERROR :DATUM #:RESULT134
                                         :EXPECTED-TYPE 'FUNCTION))
                              #:RESULT134)))))
           #'INSPECT-ADD))
 'INSPECT-ADD)
FLETC EXPANSION

(LET ((#:LOCAL-FUNCTION135
       (HOL2CL.RUNTIME:LAMBDAC (A B C)
         (+ A B C))))
  (FLET ((FOO (&REST #:ARGUMENTS136)
           (APPLY #:LOCAL-FUNCTION135 #:ARGUMENTS136)))
    (FOO 1 2 3)))
DEFUNC ENTRY
; disassembly for (LABELS INSPECT-ADD :IN "/workspace/scratch/6bf0bb049b86/hol2cl-optional-baseline/tests/optional-inspect.lisp")
; Size: 329 bytes. Origin: #x535C8174                         ; (LABELS INSPECT-ADD :IN "/workspace/scratch/6bf0bb049b86/hol2cl-optional-baseline/tests/optional-inspect.lisp")
; 174:       498B4510         MOV RAX, [R13+16]               ; thread.binding-stack-pointer
; 178:       488945E8         MOV [RBP-24], RAX
; 17C:       4C8B5DE0         MOV R11, [RBP-32]
; 180:       4531F6           XOR R14D, R14D
; 183:       4981FB17010050   CMP R11, #x50000117             ; NIL
; 18A:       741C             JEQ L1
; 18C: L0:   4D8B5B01         MOV R11, [R11+1]
; 190:       4983C602         ADD R14, 2
; 194:       4981FB17010050   CMP R11, #x50000117             ; NIL
; 19B:       740B             JEQ L1
; 19D:       418D43F9         LEA EAX, [R11-7]
; 1A1:       A80F             TEST AL, 15
; 1A3:       74E7             JEQ L0
; 1A5:       CC4C             INT3 76                         ; OBJECT-NOT-LIST-ERROR
; 1A7:       2C               BYTE #X2C                       ; R11(d)
; 1A8: L1:   4983FE06         CMP R14, 6
; 1AC:       0F8CAE000000     JL L5
; 1B2:       4C8B75E0         MOV R14, [RBP-32]
; 1B6:       488B45E0         MOV RAX, [RBP-32]
; 1BA:       488B50F9         MOV RDX, [RAX-7]
; 1BE:       488B45E0         MOV RAX, [RBP-32]
; 1C2:       4C8B7001         MOV R14, [RAX+1]
; 1C6:       458D5EF9         LEA R11D, [R14-7]
; 1CA:       41F6C30F         TEST R11B, 15
; 1CE:       0F8589000000     JNE L4
; 1D4:       498B7EF9         MOV RDI, [R14-7]
; 1D8:       4D8B7601         MOV R14, [R14+1]
; 1DC:       458D5EF9         LEA R11D, [R14-7]
; 1E0:       41F6C30F         TEST R11B, 15
; 1E4:       7574             JNE L3
; 1E6:       4D8B7EF9         MOV R15, [R14-7]
; 1EA:       4C897DD0         MOV [RBP-48], R15
; 1EE:       4D8B7601         MOV R14, [R14+1]
; 1F2:       4C8975D8         MOV [RBP-40], R14
; 1F6:       FF142560040050   CALL [#x50000460]               ; #x52A00BE0: GENERIC-+
; 1FD:       4C8B7DD0         MOV R15, [RBP-48]
; 201:       4C8B75D8         MOV R14, [RBP-40]
; 205:       498BFF           MOV RDI, R15
; 208:       FF142560040050   CALL [#x50000460]               ; #x52A00BE0: GENERIC-+
; 20F:       4C8B75D8         MOV R14, [RBP-40]
; 213:       488BF2           MOV RSI, RDX
; 216:       4981FE17010050   CMP R14, #x50000117             ; NIL
; 21D:       7506             JNE L2
; 21F:       488BE5           MOV RSP, RBP
; 222:       F8               CLC
; 223:       5D               POP RBP
; 224:       C3               RET
; 225: L2:   4C8D7424F0       LEA R14, [RSP-16]
; 22A:       4883EC28         SUB RSP, 40
; 22E:       BA4FA51450       MOV EDX, #x5014A54F             ; 'TYPE-ERROR
; 233:       BF5F241250       MOV EDI, #x5012245F             ; ':DATUM
; 238:       49C746F02F241250 MOV QWORD PTR [R14-16], #x5012242F  ; ':EXPECTED-TYPE
; 240:       49C746E8AFFB1450 MOV QWORD PTR [R14-24], #x5014FBAF  ; 'FUNCTION
; 248:       B90A000000       MOV ECX, 10
; 24D:       49892E           MOV [R14], RBP
; 250:       498BEE           MOV RBP, R14
; 253:       B842242550       MOV EAX, #x50252442             ; #<FDEFN ERROR>
; 258:       FFD0             CALL RAX
; 25A: L3:   CC4C             INT3 76                         ; OBJECT-NOT-LIST-ERROR
; 25C:       38               BYTE #X38                       ; R14(d)
; 25D: L4:   CC4C             INT3 76                         ; OBJECT-NOT-LIST-ERROR
; 25F:       38               BYTE #X38                       ; R14(d)
; 260: L5:   488B05B9FDFFFF   MOV RAX, [RIP-583]              ; #<SB-KERNEL:FDEFN HOL2CL.RUNTIME:PARTIAL>
; 267:       4C8B7801         MOV R15, [RAX+1]
; 26B:       4180FF17         CMP R15B, 23
; 26F:       7449             JEQ L8
; 271:       4C8B35D8FDFFFF   MOV R14, [RIP-552]              ; #<FUNCTION (LABELS INSPECT-ADD :IN "/workspace/scratch/6bf0bb049b86/hol2cl-optional-baseline/tests/optional-inspect.lisp") {535C80BB}>
; 278:       488BF4           MOV RSI, RSP
; 27B:       4156             PUSH R14
; 27D:       4C8B5DE0         MOV R11, [RBP-32]
; 281: L6:   4981FB17010050   CMP R11, #x50000117             ; NIL
; 288:       7414             JEQ L7
; 28A:       41FF73F9         PUSH QWORD PTR [R11-7]
; 28E:       4D8B5B01         MOV R11, [R11+1]
; 292:       418D43F9         LEA EAX, [R11-7]
; 296:       A80F             TEST AL, 15
; 298:       74E7             JEQ L6
; 29A:       CC0A             INT3 10                         ; cerror trap
; 29C:       06               BYTE #X06                       ; BOGUS-ARG-TO-VALUES-LIST-ERROR
; 29D:       2C               BYTE #X2C                       ; R11(d)
; 29E: L7:   498BC7           MOV RAX, R15
; 2A1:       FF242510040050   JMP [#x50000410]                ; #x52A007D0: TAIL-CALL-VARIABLE
; 2A8:       CC10             INT3 16                         ; Invalid argument count trap
; 2AA:       51               PUSH RCX
; 2AB:       50               PUSH RAX
; 2AC:       FF1425C0030050   CALL [#x500003C0]               ; #x52A004A0: LISTIFY-&REST
; 2B3:       415F             POP R15
; 2B5:       E9AEFEFFFF       JMP #x535C8168                  ; #<FUNCTION (LABELS INSPECT-ADD :IN "/workspace/scratch/6bf0bb049b86/hol2cl-optional-baseline/tests/optional-inspect.lisp") {535C80BB}>
; 2BA: L8:   CC14             INT3 20                         ; UNDEFINED-FUN-ERROR
; 2BC:       00               BYTE #X00                       ; RAX(d)
NAMED CALL
; disassembly for INSPECT-CALL
; Size: 40 bytes. Origin: #x535C833C                          ; INSPECT-CALL
; 3C:       498B4510         MOV RAX, [R13+16]                ; thread.binding-stack-pointer
; 40:       488945F8         MOV [RBP-8], RAX
; 44:       BA02000000       MOV EDX, 2
; 49:       BF04000000       MOV EDI, 4
; 4E:       BE06000000       MOV ESI, 6
; 53:       B906000000       MOV ECX, 6
; 58:       FF7508           PUSH QWORD PTR [RBP+8]
; 5B:       B802F82E50       MOV EAX, #x502EF802              ; #<FDEFN INSPECT-ADD>
; 60:       FFE0             JMP RAX
; 62:       CC10             INT3 16                          ; Invalid argument count trap
LAMBDAC ENTRY
; disassembly for (LABELS #:CURRIED137 :IN "/workspace/scratch/6bf0bb049b86/hol2cl-optional-baseline/tests/optional-inspect.lisp")
; Size: 329 bytes. Origin: #x535C8514                         ; (LABELS #:CURRIED137 :IN "/workspace/scratch/6bf0bb049b86/hol2cl-optional-baseline/tests/optional-inspect.lisp")
; 514:       498B4510         MOV RAX, [R13+16]               ; thread.binding-stack-pointer
; 518:       488945E8         MOV [RBP-24], RAX
; 51C:       4C8B5DE0         MOV R11, [RBP-32]
; 520:       4531F6           XOR R14D, R14D
; 523:       4981FB17010050   CMP R11, #x50000117             ; NIL
; 52A:       741C             JEQ L1
; 52C: L0:   4D8B5B01         MOV R11, [R11+1]
; 530:       4983C602         ADD R14, 2
; 534:       4981FB17010050   CMP R11, #x50000117             ; NIL
; 53B:       740B             JEQ L1
; 53D:       418D43F9         LEA EAX, [R11-7]
; 541:       A80F             TEST AL, 15
; 543:       74E7             JEQ L0
; 545:       CC4C             INT3 76                         ; OBJECT-NOT-LIST-ERROR
; 547:       2C               BYTE #X2C                       ; R11(d)
; 548: L1:   4983FE06         CMP R14, 6
; 54C:       0F8CAE000000     JL L5
; 552:       4C8B75E0         MOV R14, [RBP-32]
; 556:       488B45E0         MOV RAX, [RBP-32]
; 55A:       488B50F9         MOV RDX, [RAX-7]
; 55E:       488B45E0         MOV RAX, [RBP-32]
; 562:       4C8B7001         MOV R14, [RAX+1]
; 566:       458D5EF9         LEA R11D, [R14-7]
; 56A:       41F6C30F         TEST R11B, 15
; 56E:       0F8589000000     JNE L4
; 574:       498B7EF9         MOV RDI, [R14-7]
; 578:       4D8B7601         MOV R14, [R14+1]
; 57C:       458D5EF9         LEA R11D, [R14-7]
; 580:       41F6C30F         TEST R11B, 15
; 584:       7574             JNE L3
; 586:       4D8B7EF9         MOV R15, [R14-7]
; 58A:       4C897DD0         MOV [RBP-48], R15
; 58E:       4D8B7601         MOV R14, [R14+1]
; 592:       4C8975D8         MOV [RBP-40], R14
; 596:       FF142560040050   CALL [#x50000460]               ; #x52A00BE0: GENERIC-+
; 59D:       4C8B7DD0         MOV R15, [RBP-48]
; 5A1:       4C8B75D8         MOV R14, [RBP-40]
; 5A5:       498BFF           MOV RDI, R15
; 5A8:       FF142560040050   CALL [#x50000460]               ; #x52A00BE0: GENERIC-+
; 5AF:       4C8B75D8         MOV R14, [RBP-40]
; 5B3:       488BF2           MOV RSI, RDX
; 5B6:       4981FE17010050   CMP R14, #x50000117             ; NIL
; 5BD:       7506             JNE L2
; 5BF:       488BE5           MOV RSP, RBP
; 5C2:       F8               CLC
; 5C3:       5D               POP RBP
; 5C4:       C3               RET
; 5C5: L2:   4C8D7424F0       LEA R14, [RSP-16]
; 5CA:       4883EC28         SUB RSP, 40
; 5CE:       BA4FA51450       MOV EDX, #x5014A54F             ; 'TYPE-ERROR
; 5D3:       BF5F241250       MOV EDI, #x5012245F             ; ':DATUM
; 5D8:       49C746F02F241250 MOV QWORD PTR [R14-16], #x5012242F  ; ':EXPECTED-TYPE
; 5E0:       49C746E8AFFB1450 MOV QWORD PTR [R14-24], #x5014FBAF  ; 'FUNCTION
; 5E8:       B90A000000       MOV ECX, 10
; 5ED:       49892E           MOV [R14], RBP
; 5F0:       498BEE           MOV RBP, R14
; 5F3:       B842242550       MOV EAX, #x50252442             ; #<FDEFN ERROR>
; 5F8:       FFD0             CALL RAX
; 5FA: L3:   CC4C             INT3 76                         ; OBJECT-NOT-LIST-ERROR
; 5FC:       38               BYTE #X38                       ; R14(d)
; 5FD: L4:   CC4C             INT3 76                         ; OBJECT-NOT-LIST-ERROR
; 5FF:       38               BYTE #X38                       ; R14(d)
; 600: L5:   488B05D1FDFFFF   MOV RAX, [RIP-559]              ; #<SB-KERNEL:FDEFN HOL2CL.RUNTIME:PARTIAL>
; 607:       4C8B7801         MOV R15, [RAX+1]
; 60B:       4180FF17         CMP R15B, 23
; 60F:       7449             JEQ L8
; 611:       4C8B35E8FDFFFF   MOV R14, [RIP-536]              ; #<FUNCTION (LABELS #:CURRIED137 :IN "/workspace/scratch/6bf0bb049b86/hol2cl-optional-baseline/tests/optional-inspect.lisp") {535C845B}>
; 618:       488BF4           MOV RSI, RSP
; 61B:       4156             PUSH R14
; 61D:       4C8B5DE0         MOV R11, [RBP-32]
; 621: L6:   4981FB17010050   CMP R11, #x50000117             ; NIL
; 628:       7414             JEQ L7
; 62A:       41FF73F9         PUSH QWORD PTR [R11-7]
; 62E:       4D8B5B01         MOV R11, [R11+1]
; 632:       418D43F9         LEA EAX, [R11-7]
; 636:       A80F             TEST AL, 15
; 638:       74E7             JEQ L6
; 63A:       CC0A             INT3 10                         ; cerror trap
; 63C:       06               BYTE #X06                       ; BOGUS-ARG-TO-VALUES-LIST-ERROR
; 63D:       2C               BYTE #X2C                       ; R11(d)
; 63E: L7:   498BC7           MOV RAX, R15
; 641:       FF242510040050   JMP [#x50000410]                ; #x52A007D0: TAIL-CALL-VARIABLE
; 648:       CC10             INT3 16                         ; Invalid argument count trap
; 64A:       51               PUSH RCX
; 64B:       50               PUSH RAX
; 64C:       FF1425C0030050   CALL [#x500003C0]               ; #x52A004A0: LISTIFY-&REST
; 653:       415F             POP R15
; 655:       E9AEFEFFFF       JMP #x535C8508                  ; #<FUNCTION (LABELS #:CURRIED137 :IN "/workspace/scratch/6bf0bb049b86/hol2cl-optional-baseline/tests/optional-inspect.lisp") {535C845B}>
; 65A: L8:   CC14             INT3 20                         ; UNDEFINED-FUN-ERROR
; 65C:       00               BYTE #X00                       ; RAX(d)
LABELSC ENTRY
; disassembly for (LABELS FOO :IN "/workspace/scratch/6bf0bb049b86/hol2cl-optional-baseline/tests/optional-inspect.lisp")
; Size: 329 bytes. Origin: #x535C8814                         ; (LABELS FOO :IN "/workspace/scratch/6bf0bb049b86/hol2cl-optional-baseline/tests/optional-inspect.lisp")
; 814:       498B4510         MOV RAX, [R13+16]               ; thread.binding-stack-pointer
; 818:       488945E8         MOV [RBP-24], RAX
; 81C:       4C8B5DE0         MOV R11, [RBP-32]
; 820:       4531F6           XOR R14D, R14D
; 823:       4981FB17010050   CMP R11, #x50000117             ; NIL
; 82A:       741C             JEQ L1
; 82C: L0:   4D8B5B01         MOV R11, [R11+1]
; 830:       4983C602         ADD R14, 2
; 834:       4981FB17010050   CMP R11, #x50000117             ; NIL
; 83B:       740B             JEQ L1
; 83D:       418D43F9         LEA EAX, [R11-7]
; 841:       A80F             TEST AL, 15
; 843:       74E7             JEQ L0
; 845:       CC4C             INT3 76                         ; OBJECT-NOT-LIST-ERROR
; 847:       2C               BYTE #X2C                       ; R11(d)
; 848: L1:   4983FE06         CMP R14, 6
; 84C:       0F8CAE000000     JL L5
; 852:       4C8B75E0         MOV R14, [RBP-32]
; 856:       488B45E0         MOV RAX, [RBP-32]
; 85A:       488B50F9         MOV RDX, [RAX-7]
; 85E:       488B45E0         MOV RAX, [RBP-32]
; 862:       4C8B7001         MOV R14, [RAX+1]
; 866:       458D5EF9         LEA R11D, [R14-7]
; 86A:       41F6C30F         TEST R11B, 15
; 86E:       0F8589000000     JNE L4
; 874:       498B7EF9         MOV RDI, [R14-7]
; 878:       4D8B7601         MOV R14, [R14+1]
; 87C:       458D5EF9         LEA R11D, [R14-7]
; 880:       41F6C30F         TEST R11B, 15
; 884:       7574             JNE L3
; 886:       4D8B7EF9         MOV R15, [R14-7]
; 88A:       4C897DD0         MOV [RBP-48], R15
; 88E:       4D8B7601         MOV R14, [R14+1]
; 892:       4C8975D8         MOV [RBP-40], R14
; 896:       FF142560040050   CALL [#x50000460]               ; #x52A00BE0: GENERIC-+
; 89D:       4C8B7DD0         MOV R15, [RBP-48]
; 8A1:       4C8B75D8         MOV R14, [RBP-40]
; 8A5:       498BFF           MOV RDI, R15
; 8A8:       FF142560040050   CALL [#x50000460]               ; #x52A00BE0: GENERIC-+
; 8AF:       4C8B75D8         MOV R14, [RBP-40]
; 8B3:       488BF2           MOV RSI, RDX
; 8B6:       4981FE17010050   CMP R14, #x50000117             ; NIL
; 8BD:       7506             JNE L2
; 8BF:       488BE5           MOV RSP, RBP
; 8C2:       F8               CLC
; 8C3:       5D               POP RBP
; 8C4:       C3               RET
; 8C5: L2:   4C8D7424F0       LEA R14, [RSP-16]
; 8CA:       4883EC28         SUB RSP, 40
; 8CE:       BA4FA51450       MOV EDX, #x5014A54F             ; 'TYPE-ERROR
; 8D3:       BF5F241250       MOV EDI, #x5012245F             ; ':DATUM
; 8D8:       49C746F02F241250 MOV QWORD PTR [R14-16], #x5012242F  ; ':EXPECTED-TYPE
; 8E0:       49C746E8AFFB1450 MOV QWORD PTR [R14-24], #x5014FBAF  ; 'FUNCTION
; 8E8:       B90A000000       MOV ECX, 10
; 8ED:       49892E           MOV [R14], RBP
; 8F0:       498BEE           MOV RBP, R14
; 8F3:       B842242550       MOV EAX, #x50252442             ; #<FDEFN ERROR>
; 8F8:       FFD0             CALL RAX
; 8FA: L3:   CC4C             INT3 76                         ; OBJECT-NOT-LIST-ERROR
; 8FC:       38               BYTE #X38                       ; R14(d)
; 8FD: L4:   CC4C             INT3 76                         ; OBJECT-NOT-LIST-ERROR
; 8FF:       38               BYTE #X38                       ; R14(d)
; 900: L5:   488B05D1FDFFFF   MOV RAX, [RIP-559]              ; #<SB-KERNEL:FDEFN HOL2CL.RUNTIME:PARTIAL>
; 907:       4C8B7801         MOV R15, [RAX+1]
; 90B:       4180FF17         CMP R15B, 23
; 90F:       7449             JEQ L8
; 911:       4C8B35E8FDFFFF   MOV R14, [RIP-536]              ; #<FUNCTION (LABELS FOO :IN "/workspace/scratch/6bf0bb049b86/hol2cl-optional-baseline/tests/optional-inspect.lisp") {535C875B}>
; 918:       488BF4           MOV RSI, RSP
; 91B:       4156             PUSH R14
; 91D:       4C8B5DE0         MOV R11, [RBP-32]
; 921: L6:   4981FB17010050   CMP R11, #x50000117             ; NIL
; 928:       7414             JEQ L7
; 92A:       41FF73F9         PUSH QWORD PTR [R11-7]
; 92E:       4D8B5B01         MOV R11, [R11+1]
; 932:       418D43F9         LEA EAX, [R11-7]
; 936:       A80F             TEST AL, 15
; 938:       74E7             JEQ L6
; 93A:       CC0A             INT3 10                         ; cerror trap
; 93C:       06               BYTE #X06                       ; BOGUS-ARG-TO-VALUES-LIST-ERROR
; 93D:       2C               BYTE #X2C                       ; R11(d)
; 93E: L7:   498BC7           MOV RAX, R15
; 941:       FF242510040050   JMP [#x50000410]                ; #x52A007D0: TAIL-CALL-VARIABLE
; 948:       CC10             INT3 16                         ; Invalid argument count trap
; 94A:       51               PUSH RCX
; 94B:       50               PUSH RAX
; 94C:       FF1425C0030050   CALL [#x500003C0]               ; #x52A004A0: LISTIFY-&REST
; 953:       415F             POP R15
; 955:       E9AEFEFFFF       JMP #x535C8808                  ; #<FUNCTION (LABELS FOO :IN "/workspace/scratch/6bf0bb049b86/hol2cl-optional-baseline/tests/optional-inspect.lisp") {535C875B}>
; 95A: L8:   CC14             INT3 20                         ; UNDEFINED-FUN-ERROR
; 95C:       00               BYTE #X00                       ; RAX(d)
FLETC ENTRY
; disassembly for (FLET FOO :IN "/workspace/scratch/6bf0bb049b86/hol2cl-optional-baseline/tests/optional-inspect.lisp")
; Size: 78 bytes. Origin: #x535C8CEC                          ; (FLET FOO :IN "/workspace/scratch/6bf0bb049b86/hol2cl-optional-baseline/tests/optional-inspect.lisp")
; CEC:       498B4510         MOV RAX, [R13+16]               ; thread.binding-stack-pointer
; CF0:       488945D8         MOV [RBP-40], RAX
; CF4:       48C1E102         SHL RCX, 2
; CF8:       4C8BDC           MOV R11, RSP
; CFB:       4885C9           TEST RCX, RCX
; CFE:       7414             JEQ L1
; D00:       4829CC           SUB RSP, RCX
; D03:       4829CE           SUB RSI, RCX
; D06: L0:   488B040E         MOV RAX, [RSI+RCX]
; D0A:       4883E908         SUB RCX, 8
; D0E:       4889040C         MOV [RSP+RCX], RAX
; D12:       75F2             JNE L0
; D14: L1:   488B050DFDFFFF   MOV RAX, [RIP-755]              ; #<FUNCTION (LABELS #:CURRIED4 :IN "/workspace/scratch/6bf0bb049b86/hol2cl-optional-baseline/tests/optional-inspect.lisp") {535C8A8B}>
; D1B:       498BF3           MOV RSI, R11
; D1E:       FF242510040050   JMP [#x50000410]                ; #x52A007D0: TAIL-CALL-VARIABLE
; D25:       CC10             INT3 16                         ; Invalid argument count trap
; D27:       51               PUSH RCX
; D28:       50               PUSH RAX
; D29:       FF1425C0030050   CALL [#x500003C0]               ; #x52A004A0: LISTIFY-&REST
; D30:       415F             POP R15
; D32:       E901FEFFFF       JMP #x535C8B38                  ; #<FUNCTION (LABELS #:CURRIED4 :IN "/workspace/scratch/6bf0bb049b86/hol2cl-optional-baseline/tests/optional-inspect.lisp") {535C8A8B}>
; D37:       CC14             INT3 20                         ; UNDEFINED-FUN-ERROR
; D39:       00               BYTE #X00                       ; RAX(d)
