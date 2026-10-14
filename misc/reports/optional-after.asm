DEFUNC EXPANSION

(PROGN
 (DECLAIM (FTYPE (FUNCTION (&REST T) *) INSPECT-ADD))
 (SETF (FDEFINITION 'INSPECT-ADD)
         (LABELS ((INSPECT-ADD
                      (
                       &OPTIONAL (A NIL #:SUPPLIED136) (B NIL #:SUPPLIED137)
                       (C NIL #:SUPPLIED138)
                       &REST #:EXCESS134)
                    (IF #:SUPPLIED138
                        (LET ((#:RESULT135 (PROGN (+ A B C))))
                          (IF #:EXCESS134
                              (IF (FUNCTIONP #:RESULT135)
                                  (APPLY #:RESULT135 #:EXCESS134)
                                  (ERROR 'TYPE-ERROR :DATUM #:RESULT135
                                         :EXPECTED-TYPE 'FUNCTION))
                              #:RESULT135))
                        (COND
                         ((NOT #:SUPPLIED136)
                          (HOL2CL.RUNTIME:PARTIAL #'INSPECT-ADD))
                         ((NOT #:SUPPLIED137)
                          (HOL2CL.RUNTIME:PARTIAL #'INSPECT-ADD A))
                         ((NOT #:SUPPLIED138)
                          (HOL2CL.RUNTIME:PARTIAL #'INSPECT-ADD A B))))))
           #'INSPECT-ADD))
 'INSPECT-ADD)
FLETC EXPANSION

(LET ((#:LOCAL-FUNCTION139
       (HOL2CL.RUNTIME:LAMBDAC (A B C)
         (+ A B C))))
  (FLET ((FOO
             (
              &OPTIONAL (A NIL #:SUPPLIED142) (B NIL #:SUPPLIED143)
              (C NIL #:SUPPLIED144)
              &REST #:EXCESS140)
           (IF #:SUPPLIED144
               (LET ((#:RESULT141 (PROGN (FUNCALL #:LOCAL-FUNCTION139 A B C))))
                 (IF #:EXCESS140
                     (IF (FUNCTIONP #:RESULT141)
                         (APPLY #:RESULT141 #:EXCESS140)
                         (ERROR 'TYPE-ERROR :DATUM #:RESULT141 :EXPECTED-TYPE
                                'FUNCTION))
                     #:RESULT141))
               (COND
                ((NOT #:SUPPLIED142)
                 (HOL2CL.RUNTIME:PARTIAL #:LOCAL-FUNCTION139))
                ((NOT #:SUPPLIED143)
                 (HOL2CL.RUNTIME:PARTIAL #:LOCAL-FUNCTION139 A))
                ((NOT #:SUPPLIED144)
                 (HOL2CL.RUNTIME:PARTIAL #:LOCAL-FUNCTION139 A B))))))
    (FOO 1 2 3)))
DEFUNC ENTRY
; disassembly for (LABELS INSPECT-ADD :IN "/workspace/scratch/6bf0bb049b86/hol2cl-defunc-experiment/tests/optional-inspect.lisp")
; Size: 211 bytes. Origin: #x535C83BA                         ; (LABELS INSPECT-ADD :IN "/workspace/scratch/6bf0bb049b86/hol2cl-defunc-experiment/tests/optional-inspect.lisp")
; 3BA:       498B4510         MOV RAX, [R13+16]               ; thread.binding-stack-pointer
; 3BE:       488945D8         MOV [RBP-40], RAX
; 3C2:       48817D9017010050 CMP QWORD PTR [RBP-112], #x50000117  ; NIL
; 3CA:       7562             JNE L2
; 3CC:       48817DB017010050 CMP QWORD PTR [RBP-80], #x50000117  ; NIL
; 3D4:       7442             JEQ L1
; 3D6:       48817DA017010050 CMP QWORD PTR [RBP-96], #x50000117  ; NIL
; 3DE:       741E             JEQ L0
; 3E0:       488B15A9FEFFFF   MOV RDX, [RIP-343]              ; #<FUNCTION (LABELS INSPECT-ADD :IN "/workspace/scratch/6bf0bb049b86/hol2cl-defunc-experiment/tests/optional-inspect.lisp") {535C82FB}>
; 3E7:       488B7DB8         MOV RDI, [RBP-72]
; 3EB:       488B75A8         MOV RSI, [RBP-88]
; 3EF:       B906000000       MOV ECX, 6
; 3F4:       FF7508           PUSH QWORD PTR [RBP+8]
; 3F7:       B8628D2E50       MOV EAX, #x502E8D62             ; #<FDEFN HOL2CL.RUNTIME:PARTIAL>
; 3FC:       FFE0             JMP RAX
; 3FE: L0:   488B158BFEFFFF   MOV RDX, [RIP-373]              ; #<FUNCTION (LABELS INSPECT-ADD :IN "/workspace/scratch/6bf0bb049b86/hol2cl-defunc-experiment/tests/optional-inspect.lisp") {535C82FB}>
; 405:       488B7DB8         MOV RDI, [RBP-72]
; 409:       B904000000       MOV ECX, 4
; 40E:       FF7508           PUSH QWORD PTR [RBP+8]
; 411:       B8628D2E50       MOV EAX, #x502E8D62             ; #<FDEFN HOL2CL.RUNTIME:PARTIAL>
; 416:       FFE0             JMP RAX
; 418: L1:   488B1571FEFFFF   MOV RDX, [RIP-399]              ; #<FUNCTION (LABELS INSPECT-ADD :IN "/workspace/scratch/6bf0bb049b86/hol2cl-defunc-experiment/tests/optional-inspect.lisp") {535C82FB}>
; 41F:       B902000000       MOV ECX, 2
; 424:       FF7508           PUSH QWORD PTR [RBP+8]
; 427:       B8628D2E50       MOV EAX, #x502E8D62             ; #<FDEFN HOL2CL.RUNTIME:PARTIAL>
; 42C:       FFE0             JMP RAX
; 42E: L2:   488B55B8         MOV RDX, [RBP-72]
; 432:       488B7DA8         MOV RDI, [RBP-88]
; 436:       FF142560040050   CALL [#x50000460]               ; #x52A00BE0: GENERIC-+
; 43D:       488B7D98         MOV RDI, [RBP-104]
; 441:       FF142560040050   CALL [#x50000460]               ; #x52A00BE0: GENERIC-+
; 448:       488BF2           MOV RSI, RDX
; 44B:       48837D8800       CMP QWORD PTR [RBP-120], 0
; 450:       7506             JNE L3
; 452:       488BE5           MOV RSP, RBP
; 455:       F8               CLC
; 456:       5D               POP RBP
; 457:       C3               RET
; 458: L3:   4C8D5C24F0       LEA R11, [RSP-16]
; 45D:       4883EC28         SUB RSP, 40
; 461:       BA4FA51450       MOV EDX, #x5014A54F             ; 'TYPE-ERROR
; 466:       BF5F241250       MOV EDI, #x5012245F             ; ':DATUM
; 46B:       49C743F02F241250 MOV QWORD PTR [R11-16], #x5012242F  ; ':EXPECTED-TYPE
; 473:       49C743E8AFFB1450 MOV QWORD PTR [R11-24], #x5014FBAF  ; 'FUNCTION
; 47B:       B90A000000       MOV ECX, 10
; 480:       49892B           MOV [R11], RBP
; 483:       498BEB           MOV RBP, R11
; 486:       B842242550       MOV EAX, #x50252442             ; #<FDEFN ERROR>
; 48B:       FFD0             CALL RAX
NAMED CALL
; disassembly for INSPECT-CALL
; Size: 40 bytes. Origin: #x535C856C                          ; INSPECT-CALL
; 6C:       498B4510         MOV RAX, [R13+16]                ; thread.binding-stack-pointer
; 70:       488945F8         MOV [RBP-8], RAX
; 74:       BA02000000       MOV EDX, 2
; 79:       BF04000000       MOV EDI, 4
; 7E:       BE06000000       MOV ESI, 6
; 83:       B906000000       MOV ECX, 6
; 88:       FF7508           PUSH QWORD PTR [RBP+8]
; 8B:       B802F82E50       MOV EAX, #x502EF802              ; #<FDEFN INSPECT-ADD>
; 90:       FFE0             JMP RAX
; 92:       CC10             INT3 16                          ; Invalid argument count trap
LAMBDAC ENTRY
; disassembly for (LABELS #:CURRIED145 :IN "/workspace/scratch/6bf0bb049b86/hol2cl-defunc-experiment/tests/optional-inspect.lisp")
; Size: 211 bytes. Origin: #x535C874A                         ; (LABELS #:CURRIED145 :IN "/workspace/scratch/6bf0bb049b86/hol2cl-defunc-experiment/tests/optional-inspect.lisp")
; 74A:       498B4510         MOV RAX, [R13+16]               ; thread.binding-stack-pointer
; 74E:       488945D8         MOV [RBP-40], RAX
; 752:       48817D9017010050 CMP QWORD PTR [RBP-112], #x50000117  ; NIL
; 75A:       7562             JNE L2
; 75C:       48817DB017010050 CMP QWORD PTR [RBP-80], #x50000117  ; NIL
; 764:       7442             JEQ L1
; 766:       48817DA017010050 CMP QWORD PTR [RBP-96], #x50000117  ; NIL
; 76E:       741E             JEQ L0
; 770:       488B15B9FEFFFF   MOV RDX, [RIP-327]              ; #<FUNCTION (LABELS #:CURRIED145 :IN "/workspace/scratch/6bf0bb049b86/hol2cl-defunc-experiment/tests/optional-inspect.lisp") {535C868B}>
; 777:       488B7DB8         MOV RDI, [RBP-72]
; 77B:       488B75A8         MOV RSI, [RBP-88]
; 77F:       B906000000       MOV ECX, 6
; 784:       FF7508           PUSH QWORD PTR [RBP+8]
; 787:       B8628D2E50       MOV EAX, #x502E8D62             ; #<FDEFN HOL2CL.RUNTIME:PARTIAL>
; 78C:       FFE0             JMP RAX
; 78E: L0:   488B159BFEFFFF   MOV RDX, [RIP-357]              ; #<FUNCTION (LABELS #:CURRIED145 :IN "/workspace/scratch/6bf0bb049b86/hol2cl-defunc-experiment/tests/optional-inspect.lisp") {535C868B}>
; 795:       488B7DB8         MOV RDI, [RBP-72]
; 799:       B904000000       MOV ECX, 4
; 79E:       FF7508           PUSH QWORD PTR [RBP+8]
; 7A1:       B8628D2E50       MOV EAX, #x502E8D62             ; #<FDEFN HOL2CL.RUNTIME:PARTIAL>
; 7A6:       FFE0             JMP RAX
; 7A8: L1:   488B1581FEFFFF   MOV RDX, [RIP-383]              ; #<FUNCTION (LABELS #:CURRIED145 :IN "/workspace/scratch/6bf0bb049b86/hol2cl-defunc-experiment/tests/optional-inspect.lisp") {535C868B}>
; 7AF:       B902000000       MOV ECX, 2
; 7B4:       FF7508           PUSH QWORD PTR [RBP+8]
; 7B7:       B8628D2E50       MOV EAX, #x502E8D62             ; #<FDEFN HOL2CL.RUNTIME:PARTIAL>
; 7BC:       FFE0             JMP RAX
; 7BE: L2:   488B55B8         MOV RDX, [RBP-72]
; 7C2:       488B7DA8         MOV RDI, [RBP-88]
; 7C6:       FF142560040050   CALL [#x50000460]               ; #x52A00BE0: GENERIC-+
; 7CD:       488B7D98         MOV RDI, [RBP-104]
; 7D1:       FF142560040050   CALL [#x50000460]               ; #x52A00BE0: GENERIC-+
; 7D8:       488BF2           MOV RSI, RDX
; 7DB:       48837D8800       CMP QWORD PTR [RBP-120], 0
; 7E0:       7506             JNE L3
; 7E2:       488BE5           MOV RSP, RBP
; 7E5:       F8               CLC
; 7E6:       5D               POP RBP
; 7E7:       C3               RET
; 7E8: L3:   4C8D5C24F0       LEA R11, [RSP-16]
; 7ED:       4883EC28         SUB RSP, 40
; 7F1:       BA4FA51450       MOV EDX, #x5014A54F             ; 'TYPE-ERROR
; 7F6:       BF5F241250       MOV EDI, #x5012245F             ; ':DATUM
; 7FB:       49C743F02F241250 MOV QWORD PTR [R11-16], #x5012242F  ; ':EXPECTED-TYPE
; 803:       49C743E8AFFB1450 MOV QWORD PTR [R11-24], #x5014FBAF  ; 'FUNCTION
; 80B:       B90A000000       MOV ECX, 10
; 810:       49892B           MOV [R11], RBP
; 813:       498BEB           MOV RBP, R11
; 816:       B842242550       MOV EAX, #x50252442             ; #<FDEFN ERROR>
; 81B:       FFD0             CALL RAX
LABELSC ENTRY
; disassembly for (LABELS FOO :IN "/workspace/scratch/6bf0bb049b86/hol2cl-defunc-experiment/tests/optional-inspect.lisp")
; Size: 211 bytes. Origin: #x535C8A3A                         ; (LABELS FOO :IN "/workspace/scratch/6bf0bb049b86/hol2cl-defunc-experiment/tests/optional-inspect.lisp")
; A3A:       498B4510         MOV RAX, [R13+16]               ; thread.binding-stack-pointer
; A3E:       488945D8         MOV [RBP-40], RAX
; A42:       48817D9017010050 CMP QWORD PTR [RBP-112], #x50000117  ; NIL
; A4A:       7562             JNE L2
; A4C:       48817DB017010050 CMP QWORD PTR [RBP-80], #x50000117  ; NIL
; A54:       7442             JEQ L1
; A56:       48817DA017010050 CMP QWORD PTR [RBP-96], #x50000117  ; NIL
; A5E:       741E             JEQ L0
; A60:       488B15B9FEFFFF   MOV RDX, [RIP-327]              ; #<FUNCTION (LABELS FOO :IN "/workspace/scratch/6bf0bb049b86/hol2cl-defunc-experiment/tests/optional-inspect.lisp") {535C897B}>
; A67:       488B7DB8         MOV RDI, [RBP-72]
; A6B:       488B75A8         MOV RSI, [RBP-88]
; A6F:       B906000000       MOV ECX, 6
; A74:       FF7508           PUSH QWORD PTR [RBP+8]
; A77:       B8628D2E50       MOV EAX, #x502E8D62             ; #<FDEFN HOL2CL.RUNTIME:PARTIAL>
; A7C:       FFE0             JMP RAX
; A7E: L0:   488B159BFEFFFF   MOV RDX, [RIP-357]              ; #<FUNCTION (LABELS FOO :IN "/workspace/scratch/6bf0bb049b86/hol2cl-defunc-experiment/tests/optional-inspect.lisp") {535C897B}>
; A85:       488B7DB8         MOV RDI, [RBP-72]
; A89:       B904000000       MOV ECX, 4
; A8E:       FF7508           PUSH QWORD PTR [RBP+8]
; A91:       B8628D2E50       MOV EAX, #x502E8D62             ; #<FDEFN HOL2CL.RUNTIME:PARTIAL>
; A96:       FFE0             JMP RAX
; A98: L1:   488B1581FEFFFF   MOV RDX, [RIP-383]              ; #<FUNCTION (LABELS FOO :IN "/workspace/scratch/6bf0bb049b86/hol2cl-defunc-experiment/tests/optional-inspect.lisp") {535C897B}>
; A9F:       B902000000       MOV ECX, 2
; AA4:       FF7508           PUSH QWORD PTR [RBP+8]
; AA7:       B8628D2E50       MOV EAX, #x502E8D62             ; #<FDEFN HOL2CL.RUNTIME:PARTIAL>
; AAC:       FFE0             JMP RAX
; AAE: L2:   488B55B8         MOV RDX, [RBP-72]
; AB2:       488B7DA8         MOV RDI, [RBP-88]
; AB6:       FF142560040050   CALL [#x50000460]               ; #x52A00BE0: GENERIC-+
; ABD:       488B7D98         MOV RDI, [RBP-104]
; AC1:       FF142560040050   CALL [#x50000460]               ; #x52A00BE0: GENERIC-+
; AC8:       488BF2           MOV RSI, RDX
; ACB:       48837D8800       CMP QWORD PTR [RBP-120], 0
; AD0:       7506             JNE L3
; AD2:       488BE5           MOV RSP, RBP
; AD5:       F8               CLC
; AD6:       5D               POP RBP
; AD7:       C3               RET
; AD8: L3:   4C8D5C24F0       LEA R11, [RSP-16]
; ADD:       4883EC28         SUB RSP, 40
; AE1:       BA4FA51450       MOV EDX, #x5014A54F             ; 'TYPE-ERROR
; AE6:       BF5F241250       MOV EDI, #x5012245F             ; ':DATUM
; AEB:       49C743F02F241250 MOV QWORD PTR [R11-16], #x5012242F  ; ':EXPECTED-TYPE
; AF3:       49C743E8AFFB1450 MOV QWORD PTR [R11-24], #x5014FBAF  ; 'FUNCTION
; AFB:       B90A000000       MOV ECX, 10
; B00:       49892B           MOV [R11], RBP
; B03:       498BEB           MOV RBP, R11
; B06:       B842242550       MOV EAX, #x50252442             ; #<FDEFN ERROR>
; B0B:       FFD0             CALL RAX
FLETC ENTRY
; disassembly for (FLET FOO :IN "/workspace/scratch/6bf0bb049b86/hol2cl-defunc-experiment/tests/optional-inspect.lisp")
; Size: 382 bytes. Origin: #x535C8F4D                         ; (FLET FOO :IN "/workspace/scratch/6bf0bb049b86/hol2cl-defunc-experiment/tests/optional-inspect.lisp")
; 8F4D:       498B4510         MOV RAX, [R13+16]              ; thread.binding-stack-pointer
; 8F51:       488945B0         MOV [RBP-80], RAX
; 8F55:       4881BD58FFFFFF17010050 CMP QWORD PTR [RBP-168], #x50000117  ; NIL
; 8F60:       7565             JNE L2
; 8F62:       4881BD70FFFFFF17010050 CMP QWORD PTR [RBP-144], #x50000117  ; NIL
; 8F6D:       7442             JEQ L1
; 8F6F:       4881BD68FFFFFF17010050 CMP QWORD PTR [RBP-152], #x50000117  ; NIL
; 8F7A:       741C             JEQ L0
; 8F7C:       488B15B5FCFFFF   MOV RDX, [RIP-843]             ; #<FUNCTION (LABELS #:CURRIED4 :IN "/workspace/scratch/6bf0bb049b86/hol2cl-defunc-experiment/tests/optional-inspect.lisp") {535C8C9B}>
; 8F83:       498BF8           MOV RDI, R8
; 8F86:       498BF2           MOV RSI, R10
; 8F89:       B906000000       MOV ECX, 6
; 8F8E:       FF7508           PUSH QWORD PTR [RBP+8]
; 8F91:       B8628D2E50       MOV EAX, #x502E8D62            ; #<FDEFN HOL2CL.RUNTIME:PARTIAL>
; 8F96:       FFE0             JMP RAX
; 8F98: L0:   488B1599FCFFFF   MOV RDX, [RIP-871]             ; #<FUNCTION (LABELS #:CURRIED4 :IN "/workspace/scratch/6bf0bb049b86/hol2cl-defunc-experiment/tests/optional-inspect.lisp") {535C8C9B}>
; 8F9F:       498BF8           MOV RDI, R8
; 8FA2:       B904000000       MOV ECX, 4
; 8FA7:       FF7508           PUSH QWORD PTR [RBP+8]
; 8FAA:       B8628D2E50       MOV EAX, #x502E8D62            ; #<FDEFN HOL2CL.RUNTIME:PARTIAL>
; 8FAF:       FFE0             JMP RAX
; 8FB1: L1:   488B1580FCFFFF   MOV RDX, [RIP-896]             ; #<FUNCTION (LABELS #:CURRIED4 :IN "/workspace/scratch/6bf0bb049b86/hol2cl-defunc-experiment/tests/optional-inspect.lisp") {535C8C9B}>
; 8FB8:       B902000000       MOV ECX, 2
; 8FBD:       FF7508           PUSH QWORD PTR [RBP+8]
; 8FC0:       B8628D2E50       MOV EAX, #x502E8D62            ; #<FDEFN HOL2CL.RUNTIME:PARTIAL>
; 8FC5:       FFE0             JMP RAX
; 8FC7: L2:   488BCD           MOV RCX, RBP
; 8FCA:       4C898548FFFFFF   MOV [RBP-184], R8
; 8FD1:       4C899540FFFFFF   MOV [RBP-192], R10
; 8FD8:       4C898D38FFFFFF   MOV [RBP-200], R9
; 8FDF:       4C8D7424F0       LEA R14, [RSP-16]
; 8FE4:       4881ECD8000000   SUB RSP, 216
; 8FEB:       498BC0           MOV RAX, R8
; 8FEE:       4D8BFA           MOV R15, R10
; 8FF1:       488B9D60FFFFFF   MOV RBX, [RBP-160]
; 8FF8:       49890E           MOV [R14], RCX
; 8FFB:       498BEE           MOV RBP, R14
; 8FFE:       E8EF000000       CALL #x535C90F2                ; #<FUNCTION (FLET FOO :IN "/workspace/scratch/6bf0bb049b86/hol2cl-defunc-experiment/tests/optional-inspect.lisp") {535C8E7B}>
; 9003:       480F42E3         CMOVB RSP, RBX
; 9007:       4C8B8D38FFFFFF   MOV R9, [RBP-200]
; 900E:       4C8B9540FFFFFF   MOV R10, [RBP-192]
; 9015:       4C8B8548FFFFFF   MOV R8, [RBP-184]
; 901C:       488BF2           MOV RSI, RDX
; 901F:       4D85C9           TEST R9, R9
; 9022:       7506             JNE L3
; 9024:       488BE5           MOV RSP, RBP
; 9027:       F8               CLC
; 9028:       5D               POP RBP
; 9029:       C3               RET
; 902A: L3:   448D5AF5         LEA R11D, [RDX-11]
; 902E:       41F6C30F         TEST R11B, 15
; 9032:       7538             JNE L6
; 9034:       488BB550FFFFFF   MOV RSI, [RBP-176]
; 903B:       4A8D0C8D00000000 LEA RCX, [R9*4]
; 9043:       4C8BDC           MOV R11, RSP
; 9046:       4885C9           TEST RCX, RCX
; 9049:       7414             JEQ L5
; 904B:       4829CC           SUB RSP, RCX
; 904E:       4829CE           SUB RSI, RCX
; 9051: L4:   488B040E         MOV RAX, [RSI+RCX]
; 9055:       4883E908         SUB RCX, 8
; 9059:       4889040C         MOV [RSP+RCX], RAX
; 905D:       75F2             JNE L4
; 905F: L5:   498BF3           MOV RSI, R11
; 9062:       488BC2           MOV RAX, RDX
; 9065:       FF242510040050   JMP [#x50000410]               ; #x52A007D0: TAIL-CALL-VARIABLE
; 906C: L6:   4C8D7424F0       LEA R14, [RSP-16]
; 9071:       4883EC28         SUB RSP, 40
; 9075:       BA4FA51450       MOV EDX, #x5014A54F            ; 'TYPE-ERROR
; 907A:       BF5F241250       MOV EDI, #x5012245F            ; ':DATUM
; 907F:       49C746F02F241250 MOV QWORD PTR [R14-16], #x5012242F  ; ':EXPECTED-TYPE
; 9087:       49C746E8AFFB1450 MOV QWORD PTR [R14-24], #x5014FBAF  ; 'FUNCTION
; 908F:       4C898548FFFFFF   MOV [RBP-184], R8
; 9096:       4C899540FFFFFF   MOV [RBP-192], R10
; 909D:       4C898D38FFFFFF   MOV [RBP-200], R9
; 90A4:       B90A000000       MOV ECX, 10
; 90A9:       49892E           MOV [R14], RBP
; 90AC:       498BEE           MOV RBP, R14
; 90AF:       B842242550       MOV EAX, #x50252442            ; #<FDEFN ERROR>
; 90B4:       FFD0             CALL RAX
; 90B6:       4C8B8D38FFFFFF   MOV R9, [RBP-200]
; 90BD:       4C8B9540FFFFFF   MOV R10, [RBP-192]
; 90C4:       4C8B8548FFFFFF   MOV R8, [RBP-184]
