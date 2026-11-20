; ==========================================================================
;  LIBRARY MANAGEMENT SYSTEM
;
;  Features :
;   - Admin / Member login, Exit confirmation (Windows API MessageBoxA)
;   - Book management  : add, remove, display, search, sort by borrow count
;   - Member management: add, remove, search, display, history, ranking
;   - Transactions, Recent Returns (STACK / LIFO), Statistics
;   - Member panel     : view, search, borrow, return (late fine), reserve
;                        (QUEUE / FIFO), history, recommendations
;   - File storage     : books.txt, members.txt, trans.txt, reserve.txt
;
;  Admin login   : username = admin     password = admin123
;  First member  : added by admin (IDs start from 1001)
;  Rules         : loan period 14 days, fine Rs. 5 per late day,
;                  max 3 books borrowed at once
; ==========================================================================

INCLUDE Irvine32.inc
INCLUDELIB user32.lib

MessageBoxA PROTO, hWnd:DWORD, lpText:PTR BYTE, lpCaption:PTR BYTE, uType:DWORD

; ------------------------------- constants --------------------------------
MAX_BOOKS    = 50
MAX_MEMBERS  = 30
MAX_TRANS    = 200
MAX_RES      = 50
MAX_STACK    = 50
NAME_LEN     = 30          ; 29 characters + null
MAX_BORROW   = 3
LOAN_DAYS    = 14
FINE_PER_DAY = 5

; ------------------------------- colours ----------------------------------
BANNER_CLR = lightGreen                    ; neon green text (banner)

SETCOLOR MACRO clr                         ; change text colour, keeps eax
    push eax
    mov  eax, clr
    call SetTextColor
    pop  eax
ENDM

.data
; ------------------------------- captions ---------------------------------
capInfo     BYTE "Smart Library - Information",0
capError    BYTE "Smart Library - Error",0
capWarn     BYTE "Smart Library - Warning",0
capConfirm  BYTE "Smart Library - Confirm",0

; ------------------------------- menus ------------------------------------
sBanner BYTE 0Dh,0Ah
        BYTE " _    _ _                        __  __                                       _     ___         _",0Dh,0Ah
        BYTE "| |  (_) |__ _ _ __ _ _ _ _  _  |  \/  |__ _ _ _  __ _ __ _ ___ _ __  ___ _ _| |_  / __|_  _ __| |_ ___ _ __",0Dh,0Ah
        BYTE "| |__| | '_ \ '_/ _` | '_| || | | |\/| / _` | ' \/ _` / _` / -_) '  \/ -_) ' \  _| \__ \ || (_-<  _/ -_) '  \",0Dh,0Ah
        BYTE "|____|_|_.__/_| \__,_|_|  \_, | |_|  |_\__,_|_||_\__,_\__, \___|_|_|_\___|_||_\__| |___/\_, /__/\__\___|_|_|_|",0Dh,0Ah
        BYTE "                          |__/                        |___/                             |__/",0Dh,0Ah
        BYTE 0Dh,0Ah,0
; smaller versions of the banner, used when the console window is narrower
sBannerMini BYTE 0Dh,0Ah
        BYTE "                                                __",0Dh,0Ah
        BYTE "| o|_ .__.._  |\/| _.._  _. _  _ ._ _  _ .__|_ (_    __|_ _ ._ _",0Dh,0Ah
        BYTE "|_||_)|(_||\/ |  |(_|| |(_|(_|(/_| | |(/_| ||_ __)\/_> |_(/_| | |",0Dh,0Ah
        BYTE "           /                _|                    /",0Dh,0Ah
        BYTE 0Dh,0Ah,0
sBannerTiny BYTE 0Dh,0Ah,"  ===== LIBRARY MANAGEMENT SYSTEM =====",0Dh,0Ah,0Dh,0Ah,0
sLoading  BYTE "  Loading, please wait...",0Dh,0Ah,0Dh,0Ah,0
sBarOpen  BYTE "  [",0
sBarClose BYTE "]",0Dh,0Ah,0Dh,0Ah,0
sReady    BYTE "  Ready!",0Dh,0Ah,0
sMainMenu BYTE "  1. Admin Login",0Dh,0Ah
          BYTE "  2. Member Login",0Dh,0Ah
          BYTE "  3. Exit",0Dh,0Ah,0Dh,0Ah
          BYTE "  Enter choice: ",0
sAdminMenuT BYTE 0Dh,0Ah,"-------------- ADMIN PANEL --------------",0Dh,0Ah,0
sAdminMenu LABEL BYTE
           BYTE "  1. Book Management",0Dh,0Ah
           BYTE "  2. Member Management",0Dh,0Ah
           BYTE "  3. Transaction Records",0Dh,0Ah
           BYTE "  4. Recent Returns",0Dh,0Ah
           BYTE "  5. Statistics",0Dh,0Ah
           BYTE "  6. Logout",0Dh,0Ah,0Dh,0Ah
           BYTE "  Enter choice: ",0
sBookMenuT BYTE 0Dh,0Ah,"------------- BOOK MANAGEMENT -------------",0Dh,0Ah,0
sBookMenu LABEL BYTE
          BYTE "  1. Add Book",0Dh,0Ah
          BYTE "  2. Remove Book",0Dh,0Ah
          BYTE "  3. Display All Books",0Dh,0Ah
          BYTE "  4. Search Book",0Dh,0Ah
          BYTE "  5. Sort Books by Borrow Count",0Dh,0Ah
          BYTE "  6. Back",0Dh,0Ah,0Dh,0Ah
          BYTE "  Enter choice: ",0
sSortMenuT BYTE 0Dh,0Ah,"---------- SORT BY BORROW COUNT ----------",0Dh,0Ah,0
sSortMenu LABEL BYTE
          BYTE "  1. Highest to Lowest",0Dh,0Ah
          BYTE "  2. Lowest to Highest",0Dh,0Ah,0Dh,0Ah
          BYTE "  Enter choice: ",0
sMemMenuT BYTE 0Dh,0Ah,"------------ MEMBER MANAGEMENT ------------",0Dh,0Ah,0
sMemMenu LABEL BYTE
         BYTE "  1. Add Member",0Dh,0Ah
         BYTE "  2. Remove Member",0Dh,0Ah
         BYTE "  3. Search Member",0Dh,0Ah
         BYTE "  4. Display All Members",0Dh,0Ah
         BYTE "  5. View Member History",0Dh,0Ah
         BYTE "  6. Member Ranking",0Dh,0Ah
         BYTE "  7. Back",0Dh,0Ah,0Dh,0Ah
         BYTE "  Enter choice: ",0
sTransMenuT BYTE 0Dh,0Ah,"----------- TRANSACTION RECORDS -----------",0Dh,0Ah,0
sTransMenu LABEL BYTE
           BYTE "  1. View Issued Books (all records)",0Dh,0Ah
           BYTE "  2. View Returned Books",0Dh,0Ah
           BYTE "  3. View Current Borrowers",0Dh,0Ah
           BYTE "  4. View Outstanding Fines",0Dh,0Ah
           BYTE "  5. Back",0Dh,0Ah,0Dh,0Ah
           BYTE "  Enter choice: ",0
sRecentMenuT BYTE 0Dh,0Ah,"-------- RECENT RETURNS (STACK / LIFO) --------",0Dh,0Ah,0
sRecentMenu LABEL BYTE
            BYTE "  1. View Most Recent Return",0Dh,0Ah
            BYTE "  2. View Recent Returns",0Dh,0Ah
            BYTE "  3. Remove Top Return",0Dh,0Ah
            BYTE "  4. Back",0Dh,0Ah,0Dh,0Ah
            BYTE "  Enter choice: ",0
sMemberMenuT BYTE 0Dh,0Ah,"-------------- MEMBER PANEL --------------",0Dh,0Ah,0
sMemberMenu LABEL BYTE
            BYTE "  1. View Books",0Dh,0Ah
            BYTE "  2. Search Books",0Dh,0Ah
            BYTE "  3. Borrow Book",0Dh,0Ah
            BYTE "  4. Return Book",0Dh,0Ah
            BYTE "  5. Reserve Book",0Dh,0Ah
            BYTE "  6. My History",0Dh,0Ah
            BYTE "  7. Recommendations",0Dh,0Ah
            BYTE "  8. Pay Fine",0Dh,0Ah
            BYTE "  9. Logout",0Dh,0Ah,0Dh,0Ah
            BYTE "  Enter choice: ",0
sWelcome BYTE 0Dh,0Ah,"  Welcome, ",0

; ------------------------------- titles / prompts -------------------------
sAdminTitle BYTE 0Dh,0Ah,"=== ADMIN LOGIN ===",0Dh,0Ah,0
sMemberTitle BYTE 0Dh,0Ah,"=== MEMBER LOGIN ===",0Dh,0Ah,0
sUser    BYTE "  Username : ",0
sPass    BYTE "  Password : ",0
sMemId   BYTE "  Member ID: ",0
sMemPin  BYTE "  PIN      : ",0
sTAddBook BYTE 0Dh,0Ah,"=== ADD BOOK ===",0Dh,0Ah,0
sTRemBook BYTE 0Dh,0Ah,"=== REMOVE BOOK ===",0Dh,0Ah,0
sTSrchBook BYTE 0Dh,0Ah,"=== SEARCH BOOK ===",0Dh,0Ah,0
sTAllBooks BYTE 0Dh,0Ah,"=== ALL BOOKS ===",0Dh,0Ah,0
sTSorted BYTE 0Dh,0Ah,"=== BOOKS SORTED BY BORROW COUNT ===",0Dh,0Ah,0
sTAddMem BYTE 0Dh,0Ah,"=== ADD MEMBER ===",0Dh,0Ah,0
sTRemMem BYTE 0Dh,0Ah,"=== REMOVE MEMBER ===",0Dh,0Ah,0
sTSrchMem BYTE 0Dh,0Ah,"=== SEARCH MEMBER ===",0Dh,0Ah,0
sTAllMem BYTE 0Dh,0Ah,"=== ALL MEMBERS ===",0Dh,0Ah,0
sTHist   BYTE 0Dh,0Ah,"=== MEMBER HISTORY ===",0Dh,0Ah,0
sTRank   BYTE 0Dh,0Ah,"=== MEMBER RANKING (by books borrowed) ===",0Dh,0Ah,0
sTTrans  BYTE 0Dh,0Ah,"=== TRANSACTION RECORDS ===",0Dh,0Ah,0
sTFines  BYTE 0Dh,0Ah,"=== OUTSTANDING FINES ===",0Dh,0Ah,0
sTRecentOne BYTE 0Dh,0Ah,"=== MOST RECENT RETURN ===",0Dh,0Ah,0
sTRecent BYTE 0Dh,0Ah,"=== RECENT RETURNS (top of stack first) ===",0Dh,0Ah,0
sTStats  BYTE 0Dh,0Ah,"=== LIBRARY STATISTICS ===",0Dh,0Ah,0Dh,0Ah,0
sTBorrow BYTE 0Dh,0Ah,"=== BORROW BOOK ===",0Dh,0Ah,0
sTReturn BYTE 0Dh,0Ah,"=== RETURN BOOK ===",0Dh,0Ah,0
sTReserve BYTE 0Dh,0Ah,"=== RESERVE BOOK ===",0Dh,0Ah,0
sTMyHist BYTE 0Dh,0Ah,"=== MY HISTORY ===",0Dh,0Ah,0
sTRecom  BYTE 0Dh,0Ah,"=== RECOMMENDATIONS ===",0Dh,0Ah,0
sPBookId BYTE "  Enter Book ID           : ",0
sPBookName BYTE "  Enter Book Name         : ",0
sPAuthor BYTE "  Enter Author            : ",0
sPCat    BYTE "  Enter Category          : ",0
sPCopies BYTE "  Enter Number of Copies  : ",0
sPMemId  BYTE "  Enter Member ID         : ",0
sPMemName BYTE "  Enter Member Name       : ",0
sPMemPin BYTE "  Enter Member PIN (number): ",0
sPDays   BYTE "  Days the book was kept  : ",0
sCurBorrowed BYTE 0Dh,0Ah,"--- Currently Borrowed Books ---",0Dh,0Ah,0
sPrevReturned BYTE 0Dh,0Ah,"--- Previously Returned Books ---",0Dh,0Ah,0
sOutFine BYTE 0Dh,0Ah,"Outstanding Fine: Rs. ",0
sFavCat  BYTE "  Your favourite category: ",0
sRecList BYTE 0Dh,0Ah,"  Books you may like:",0Dh,0Ah,0
sRecNone BYTE "  No new books found in your favourite category.",0Dh,0Ah,0
msgNoHist BYTE "  You have no borrowing history yet, so no recommendations.",0Dh,0Ah,0

; ------------------------------- table headers ----------------------------
sLine   BYTE "--------------------------------------------------------------------------------",0Dh,0Ah,0
sLineB  BYTE 93 DUP('-'),0Dh,0Ah,0          ; rule under the books table (93 columns)
sLineS  BYTE 64 DUP('-'),0Dh,0Ah,0          ; rule under member / transaction tables
sH_ID   BYTE "ID",9,0
sH_Name BYTE "Name",0
sH_Auth BYTE "Author",0
sH_Cat  BYTE "Category",0
sH_Copy BYTE "Copies  Borrows",0
sH_Bor  BYTE "Borrowed  Fine(Rs)",0
sH_Mem  BYTE "Member",9,0
sH_Book BYTE "Book",9,0
sH_Title BYTE "Title",0
sH_Stat BYTE "Status",0
sH_Fine BYTE "Fine(Rs)",0
sH_Rank BYTE "Rank",9,0
sIssued   BYTE "Issued",0
sReturned BYTE "Returned",0
sRemoved  BYTE "(removed)",0
sNoRecords BYTE "  No records found.",0Dh,0Ah,0
sNA       BYTE "N/A",0Dh,0Ah,0
sParenO   BYTE "  (",0
sParenC   BYTE ")",0Dh,0Ah,0

; ------------------------------- statistics labels ------------------------
sStTB   BYTE "  Total Books              : ",0
sStTM   BYTE "  Total Members            : ",0
sStAvail BYTE "  Available Book Copies    : ",0
sStBorrowed BYTE "  Currently Borrowed Books : ",0
sStMostBook BYTE "  Most Borrowed Book       : ",0
sStTopReader BYTE "  Top Reader               : ",0
sStPopCat BYTE "  Most Popular Category    : ",0
sRetLabel BYTE "  Most recent return:",0Dh,0Ah,0

; ------------------------------- message box texts ------------------------
adminUser BYTE "admin",0
adminPass BYTE "admin123",0
msgLoginErr  BYTE "Login failed! Invalid credentials.",0
msgNoBook    BYTE "Record Not Found: Book ID does not exist.",0
msgNoMember  BYTE "Record Not Found: Member ID does not exist.",0
msgBookAdded BYTE "Book Added Successfully!",0
msgBookDup   BYTE "A book with this ID already exists.",0
msgBookFull  BYTE "Book storage is full.",0
msgMemFull   BYTE "Member storage is full.",0
msgInvalid   BYTE "Invalid input. Please try again.",0
msgDelBookQ  BYTE "Are you sure you want to delete this book?",0
msgDelMemQ   BYTE "Are you sure you want to delete this member?",0
msgExitQ     BYTE "Do you really want to exit the system?",0
msgBookGone  BYTE "Book record removed.",0
msgMemGone   BYTE "Member record removed.",0
msgMemOk     BYTE "Member Registered Successfully!",0Dh,0Ah,"Generated Member ID: ",0
msgUnavail   BYTE "Book Unavailable: no copies left. You may reserve it.",0
msgLimit     BYTE "You have reached the maximum of 3 borrowed books.",0
msgFineBlock BYTE "You have an outstanding fine. Please pay it first.",0
msgHasBook   BYTE "You already hold this book.",0
msgQueueTurn BYTE "This book is reserved for members waiting in the queue.",0Dh,0Ah,"Please wait for your turn.",0
msgIssued    BYTE "Book Issued Successfully!",0
msgTransFull BYTE "Transaction storage is full.",0
msgInvRet    BYTE "Invalid Return: you have not borrowed this book.",0
msgRetOk     BYTE "Book returned successfully!",0Dh,0Ah,"Late fine: Rs. ",0
msgQNote1    BYTE 0Dh,0Ah,"Note: Member ID ",0
msgQNote2    BYTE " is first in the reservation queue for this book.",0
msgResAvail  BYTE "This book is available. You can borrow it directly.",0
msgResHave   BYTE "You already hold this book, so you cannot reserve it.",0
msgResDup    BYTE "You are already in the queue for this book.",0
msgResFull   BYTE "Reservation queue is full.",0
msgResOk     BYTE "Reservation Confirmed!",0Dh,0Ah,"Your FIFO queue position: ",0
msgNoRet     BYTE "No returns recorded yet.",0
msgPopped    BYTE "Top return removed from the stack.",0
msgNoFine    BYTE "You have no outstanding fine.",0
msgPaid      BYTE "Fine paid. Thank you! Amount: Rs. ",0

; ------------------------------- file names -------------------------------
fBooks   BYTE "books.txt",0
fMembers BYTE "members.txt",0
fTrans   BYTE "trans.txt",0
fReserve BYTE "reserve.txt",0

; =========================== DATA BLOCKS (saved to files) =================
; --- books ---
; Parallel arrays: index i of every array below belongs to the SAME book.
; bookActive[i] = 1 means the slot holds a real book, 0 means free / deleted.
bookId        DWORD MAX_BOOKS DUP(0)
bookName      BYTE  MAX_BOOKS*NAME_LEN DUP(0)
bookAuthor    BYTE  MAX_BOOKS*NAME_LEN DUP(0)
bookCat       BYTE  MAX_BOOKS*NAME_LEN DUP(0)
bookCopies    DWORD MAX_BOOKS DUP(0)
bookBorrowCnt DWORD MAX_BOOKS DUP(0)
bookActive    DWORD MAX_BOOKS DUP(0)

; --- members ---
; nextMemberId is the ID counter (saved in members.txt so IDs are never reused).
; memFine = unpaid fine in Rs.; memBorrowTotal = books borrowed so far (for ranking).
nextMemberId   DWORD 1001
memId          DWORD MAX_MEMBERS DUP(0)
memName        BYTE  MAX_MEMBERS*NAME_LEN DUP(0)
memPin         DWORD MAX_MEMBERS DUP(0)
memBorrowTotal DWORD MAX_MEMBERS DUP(0)
memFine        DWORD MAX_MEMBERS DUP(0)
memActive      DWORD MAX_MEMBERS DUP(0)

; --- transactions + return stack (LIFO) ---
; One row per borrow.  trReturned: 0 = still borrowed, 1 = returned.
; retTop = number of entries on the stack; the top entry is index retTop-1.
trCount    DWORD 0
trMember   DWORD MAX_TRANS DUP(0)
trBook     DWORD MAX_TRANS DUP(0)
trDays     DWORD MAX_TRANS DUP(0)
trReturned DWORD MAX_TRANS DUP(0)
trFine     DWORD MAX_TRANS DUP(0)
retTop       DWORD 0
retStackBook DWORD MAX_STACK DUP(0)
retStackMem  DWORD MAX_STACK DUP(0)

; --- reservation queue (FIFO) ---
; Entry 0 is the oldest reservation (front of the queue); new ones are added at resCount.
resCount DWORD 0
resMem   DWORD MAX_RES DUP(0)
resBook  DWORD MAX_RES DUP(0)

; ======================= TEXT FILE FORMAT STRINGS =========================
FILE_BUF_SIZE = 32768
sPipe   BYTE "|",0
sSep    BYTE " | ",0
sCrLf   BYTE 0Dh,0Ah,0
sNextIdLbl     BYTE "NextMemberID | ",0
hdrBooksFile   BYTE "BookID | Name                          | Author                        | Category                      | Copies | BorrowCount",0Dh,0Ah
               BYTE "-------+-------------------------------+-------------------------------+-------------------------------+--------+-------------",0Dh,0Ah,0
hdrMembersFile BYTE "MemberID | Name                          | PIN    | TotalBorrowed | Fine",0Dh,0Ah
               BYTE "---------+-------------------------------+--------+---------------+------",0Dh,0Ah,0
hdrTransFile   BYTE "MemberID | BookID | DaysKept | Returned(1=yes) | Fine",0Dh,0Ah
               BYTE "---------+--------+----------+-----------------+------",0Dh,0Ah,0
hdrStackFile   BYTE 0Dh,0Ah,"[RETURN STACK - bottom to top, last line = most recent]",0Dh,0Ah
               BYTE "MemberID | BookID",0Dh,0Ah
               BYTE "---------+--------",0Dh,0Ah,0
hdrResFile     BYTE "MemberID | BookID",0Dh,0Ah
               BYTE "---------+--------",0Dh,0Ah,0
fileBuf        BYTE FILE_BUF_SIZE DUP(0)
nameDst        DWORD 0
numBuf         BYTE 16 DUP(0)

; ============================ working variables ===========================
inBuf   BYTE 64 DUP(0)
inBuf2  BYTE 64 DUP(0)
msgBuf  BYTE 512 DUP(0)
curMember DWORD 0          ; slot index of logged-in member
curMemId  DWORD 0          ; ID of logged-in member
tmpId     DWORD 0
tmpSlot   DWORD 0
tmpDays   DWORD 0
tmpFine   DWORD 0
tmpA      DWORD 0
tmpN      DWORD 0
ptr1      DWORD 0
ptr2      DWORD 0
sortList   DWORD MAX_BOOKS+MAX_MEMBERS DUP(0)
sortN     DWORD 0
sortLim   DWORD 0
tmpIdx    DWORD MAX_TRANS DUP(0)
catI      DWORD 0
catJ      DWORD 0
catSum    DWORD 0
catBestSlot  SDWORD -1
catBestScore DWORD 0
dispCnt   DWORD 0
fMode     DWORD 0          ; 0 = all, 1 = returned, 2 = not returned
fMem      DWORD 0          ; 0 = every member
fileHandle DWORD 0
blkPtr    DWORD 0
blkSize   DWORD 0

.code
; ==========================================================================
;                               MAIN
; ==========================================================================
; ------------------------------------------------------------------------
; main : Program entry point.  Loads the saved data, then shows the login menu in a
;     loop until the user confirms Exit.  Admin / Member panels return here after
;     logout, and SaveAll writes everything to the text files each time.
; ------------------------------------------------------------------------
main PROC
    call LoadingBar                ; loading screen shown before the program starts
    call LoadAll                   ; restore the data saved by the last run
MainLoop:
    call Clrscr
    call PrintBanner               ; picks a banner size that fits the window
    mov  edx, OFFSET sMainMenu
    call PrintMenu
    call ReadInt   ; eax = menu choice typed by the user
    cmp  eax, 1
    je   DoAdmin
    cmp  eax, 2
    je   DoMember
    cmp  eax, 3
    je   DoExit
    jmp  MainLoop
DoAdmin:
    call AdminLogin
    cmp  eax, 1
    jne  MainLoop
    call AdminMenu
    call SaveAll   ; data is saved every time the admin logs out
    jmp  MainLoop
DoMember:
    call MemberLogin
    cmp  eax, 1
    jne  MainLoop
    call MemberMenu
    call SaveAll
    jmp  MainLoop
DoExit:
    mov  edx, OFFSET msgExitQ
    call AskBox
    cmp  eax, 6                  ; IDYES
    jne  MainLoop
    call SaveAll
    exit
main ENDP

; ==========================================================================
;                       WINDOWS API MESSAGE BOX WRAPPERS
;   edx = pointer to message text
; ==========================================================================
; ------------------------------------------------------------------------
; InfoBox : Windows API wrapper: shows an information message box.  edx = message text.
; ------------------------------------------------------------------------
InfoBox PROC
    INVOKE MessageBoxA, 0, edx, OFFSET capInfo, 40h      ; OK + information
    ret
InfoBox ENDP

; ------------------------------------------------------------------------
; ErrBox : Windows API wrapper: shows an error message box (red icon).  edx = text.
; ------------------------------------------------------------------------
ErrBox PROC
    INVOKE MessageBoxA, 0, edx, OFFSET capError, 10h     ; OK + error icon
    ret
ErrBox ENDP

; ------------------------------------------------------------------------
; WarnBox : Windows API wrapper: shows a warning message box (yellow icon).  edx = text.
; ------------------------------------------------------------------------
WarnBox PROC
    INVOKE MessageBoxA, 0, edx, OFFSET capWarn, 30h      ; OK + warning icon
    ret
WarnBox ENDP

; ------------------------------------------------------------------------
; AskBox : Windows API wrapper: Yes/No confirmation box.  edx = question.
;     Returns eax = 6 if the user pressed Yes, 7 if No.  Used before deleting a
;     book / member and before exiting.
; ------------------------------------------------------------------------
AskBox PROC                                              ; returns eax: 6 = Yes, 7 = No
    INVOKE MessageBoxA, 0, edx, OFFSET capConfirm, 24h   ; Yes/No + question icon
    ret
AskBox ENDP

; ==========================================================================
;                              HELPER PROCEDURES
; ==========================================================================
; ------------------------- coloured printing ------------------------
; ------------------------------------------------------------------------
; PrintTitle : Prints a heading in light cyan, then restores the normal colour.  edx = text.
; ------------------------------------------------------------------------
; edx = text
PrintTitle PROC                            ; headings: light cyan
    SETCOLOR lightCyan
    call WriteString
    SETCOLOR lightGray
    ret
PrintTitle ENDP

; ------------------------------------------------------------------------
; PrintMenu : Prints a menu in bright white, then restores the normal colour.  edx = text.
; ------------------------------------------------------------------------
PrintMenu PROC                             ; menu options: bright white
    SETCOLOR white
    call WriteString
    SETCOLOR lightGray
    ret
PrintMenu ENDP

; ------------------------------------------------------------------------
; PrintBanner : Prints the start-up banner in neon green on ONE line.
;     The console width is read with GetMaxXY (dx = columns) and the biggest
;     banner that fits is chosen, so the title never wraps onto a second row:
;        112 columns or more -> large lettering (110 wide)
;        67 to 111 columns   -> small lettering (65 wide)
;        fewer columns       -> plain text title
; ------------------------------------------------------------------------
PrintBanner PROC uses eax edx
    SETCOLOR BANNER_CLR
    call GetMaxXY                          ; Irvine32: dx = number of columns
    movzx edx, dx
    cmp  edx, 112
    jae  pb_large
    cmp  edx, 67
    jae  pb_small
    mov  edx, OFFSET sBannerTiny           ; very narrow window
    jmp  pb_print
pb_large:
    mov  edx, OFFSET sBanner
    jmp  pb_print
pb_small:
    mov  edx, OFFSET sBannerMini
pb_print:
    call WriteString
    SETCOLOR lightGray
    ret
PrintBanner ENDP

; ------------------------------------------------------------------------
; LoadingBar : start-up loading screen (visual effect only).
;     Shows the banner, the text "Loading, please wait..." and a bar of 40
;     block characters (ASCII 0DBh) that fills up one block at a time.
;     The pause between blocks is made with Irvine32's Delay (eax =
;     milliseconds): 40 blocks x 40 ms = about 1.6 seconds.  The bar runs on
;     a timer; it does not measure the real file loading.
; ------------------------------------------------------------------------
LoadingBar PROC uses eax ecx edx
    call Clrscr
    call PrintBanner               ; neon green banner above the bar
    mov  edx, OFFSET sLoading
    call PrintTitle                ; light cyan caption
    mov  edx, OFFSET sBarOpen
    call WriteString               ; "  ["
    SETCOLOR lightGreen            ; the bar itself is neon green
    mov  ecx, 40                   ; bar length in characters
lb_fill:
    mov  al, 0DBh                  ; solid block character
    call WriteChar
    mov  eax, 40                   ; wait 40 milliseconds
    push ecx                       ; Delay is a Windows call: keep our counter safe
    call Delay
    pop  ecx
    loop lb_fill                   ; repeat until the bar is full
    SETCOLOR lightGray
    mov  edx, OFFSET sBarClose
    call WriteString               ; "]"
    mov  edx, OFFSET sReady
    call PrintTitle                ; "Ready!"
    mov  eax, 500                  ; short pause so "Ready!" can be read
    call Delay
    ret
LoadingBar ENDP

; ------------------------------------------------------------------------
; StrAt : Address of the i-th text cell.  Strings are stored in fixed 30-byte cells,
;     so string number i starts at  base + i * NAME_LEN.
;     Input : edx = base address of the table, eax = index
;     Output: edx = address of that string (eax is preserved)
; ------------------------------------------------------------------------
; edx = base of a string table, eax = index  ->  edx = address of that string
StrAt PROC uses eax
    imul eax, NAME_LEN   ; eax = index * 30
    add  edx, eax   ; edx = address of the string number "index"
    ret
StrAt ENDP

; ------------------------------------------------------------------------
; GetName : Reads one line of text from the keyboard into the cell at edx (max 29
;     characters + null).  Any '|' typed by the user is changed to '-' because '|'
;     separates the fields in our text files and would corrupt them.
; ------------------------------------------------------------------------
; edx = destination (NAME_LEN bytes): reads a string from the keyboard
; ('|' is replaced by '-' because '|' separates fields in the text files)
GetName PROC uses eax ebx ecx edx esi edi
    mov  nameDst, edx   ; remember the buffer (registers may change inside ReadString)
    mov  ecx, NAME_LEN-1   ; max characters; 1 byte is kept for the null terminator
    call ReadString   ; Irvine: reads a line into [edx], eax = length
    mov  esi, nameDst
gn_fix:
    mov  al, [esi]
    cmp  al, 0
    je   gn_done
    cmp  al, '|'
    jne  gn_next
    mov  BYTE PTR [esi], '-'
gn_next:
    inc  esi
    jmp  gn_fix
gn_done:
    ret
GetName ENDP

; ------------------------------------------------------------------------
; PrintPad : Left-aligns text in a table column: prints the string, then adds spaces until
;     the column width is reached.  This is what keeps the tables tidy.
;     Input : edx = string, ebx = column width
; ------------------------------------------------------------------------
; edx = string, ebx = column width : prints string padded with spaces
PrintPad PROC uses eax ebx ecx edx
    push edx
    call WriteString
    pop  edx
    INVOKE Str_length, edx   ; eax = length of the text
    sub  ebx, eax   ; ebx = how many spaces are still needed
    jle  pp_done   ; text already fills the column
    mov  ecx, ebx
pp_loop:
    mov  al, ' '
    call WriteChar
    loop pp_loop   ; print ecx spaces
pp_done:
    ret
PrintPad ENDP

; ------------------------------------------------------------------------
; PrintNumPad : prints a number left-aligned in a column of fixed width.
;     The number is first converted to text (AppendNum) and then printed with
;     PrintPad, so the next column always starts at the same place.  A tab
;     cannot be used here: tab stops are every 8 columns, so the position
;     after a tab depends on how many digits the number has.
;     Input : eax = number, ebx = column width
; ------------------------------------------------------------------------
PrintNumPad PROC uses eax ebx ecx edx edi
    mov  edi, OFFSET numBuf        ; text buffer for the digits
    call AppendNum                 ; number -> text
    mov  edx, OFFSET numBuf
    call PrintPad                  ; print it padded to width ebx
    ret
PrintNumPad ENDP

; ------------------------------------------------------------------------
; PrintLabelNum : Prints a label followed by a number (used by Statistics).
;     Input : edx = label text, eax = number
; ------------------------------------------------------------------------
; edx = label, eax = number : prints "label number"
PrintLabelNum PROC uses eax edx
    SETCOLOR lightCyan
    call WriteString
    SETCOLOR yellow
    call WriteDec
    SETCOLOR lightGray
    call Crlf
    ret
PrintLabelNum ENDP

; ------------------------------------------------------------------------
; AppendStr : String append: copies the null-terminated string at esi to the output cursor
;     edi.  edi is left ON the terminating null, so the next append continues right
;     there.  We use it to build messages and file text piece by piece (Irvine32 has
;     no string-concatenation routine).
; ------------------------------------------------------------------------
; edi = cursor, esi = source : copy string, edi left at the null terminator
AppendStr PROC uses eax
as_loop:
    mov  al, [esi]   ; read one source character
    mov  [edi], al   ; write it at the output cursor
    cmp  al, 0   ; null terminator = end of string
    je   as_done
    inc  esi
    inc  edi
    jmp  as_loop
as_done:
    ret
AppendStr ENDP

; ------------------------------------------------------------------------
; AppendNum : Integer -> decimal text (like itoa).  Dividing by 10 repeatedly gives the
;     digits LAST digit first, so every digit is pushed on the stack and then
;     popped: the stack reverses the order and the digits come out correctly.
;     Input : eax = number, edi = output cursor (left on the null terminator)
; ------------------------------------------------------------------------
; eax = number, edi = cursor : append decimal text, edi left at terminator
AppendNum PROC uses eax ebx ecx edx
    mov  ebx, 10
    xor  ecx, ecx
an_div:
    xor  edx, edx
    div  ebx   ; eax = eax / 10 ; edx = remainder = last digit
    add  dl, '0'   ; digit 0..9 -> ASCII character '0'..'9'
    push edx   ; the stack reverses the digit order
    inc  ecx
    cmp  eax, 0
    jne  an_div
an_out:
    pop  edx   ; digits now come out most-significant first
    mov  [edi], dl
    inc  edi
    loop an_out
    mov  BYTE PTR [edi], 0
    ret
AppendNum ENDP

; ------------------------------------------------------------------------
; StrCompareI : case-INSENSITIVE string compare ("Suspense" = "suspense").
;     Irvine's Str_compare treats capital and small letters as different, so
;     categories are compared with this routine instead.  Both characters are
;     converted to capitals (small letter 'a'..'z' minus 32) before comparing.
;     Passwords are still compared with Str_compare (they ARE case-sensitive).
;     Input : esi = first string, edi = second string
;     Output: ZF = 1 if the strings are equal ignoring case (use je / jne)
; ------------------------------------------------------------------------
StrCompareI PROC uses eax esi edi
ci_loop:
    mov  al, [esi]
    mov  ah, [edi]
    cmp  al, 'a'                   ; small letter?  then make it a capital
    jb   ci_a
    cmp  al, 'z'
    ja   ci_a
    sub  al, 32
ci_a:
    cmp  ah, 'a'
    jb   ci_b
    cmp  ah, 'z'
    ja   ci_b
    sub  ah, 32
ci_b:
    cmp  al, ah
    jne  ci_done                   ; different characters: ZF = 0
    cmp  al, 0
    je   ci_done                   ; both strings ended together: ZF = 1
    inc  esi
    inc  edi
    jmp  ci_loop
ci_done:
    ret
StrCompareI ENDP

; ------------------------------------------------------------------------
; QueueAllows : FIFO fairness rule for borrowing.
;     A free copy must go to the members waiting in the reservation queue,
;     in the order they reserved.  The logged-in member may borrow only if
;       - nobody is waiting for the book, or
;       - there are MORE free copies than waiting members, or
;       - the member is in the queue AND his position is not greater than the
;         number of free copies (position 1 for one copy, 1 or 2 for two ...)
;     Input : eax = book ID
;     Output: eax = 1 (allowed to borrow now) or 0 (must wait for his turn)
; ------------------------------------------------------------------------
QueueAllows PROC uses ebx ecx edx esi edi
    mov  edx, eax                  ; edx = book ID
    call CountQueue                ; eax = members waiting for this book
    mov  ebx, eax
    cmp  ebx, 0
    je   qa_yes                    ; nobody waiting: free to borrow
    mov  eax, edx
    call FindBook                  ; slot of the book
    mov  ecx, bookCopies[eax*4]    ; ecx = free copies
    cmp  ecx, ebx
    ja   qa_yes                    ; more copies than people waiting
    mov  esi, 0                    ; esi = index into the queue
    mov  edi, 0                    ; edi = position among THIS book's queue
qa_loop:
    cmp  esi, resCount
    jae  qa_no                     ; end of queue and we were not in it
    cmp  resBook[esi*4], edx
    jne  qa_next                   ; entry belongs to another book
    inc  edi                       ; one more member waiting for this book
    mov  eax, resMem[esi*4]
    cmp  eax, curMemId
    jne  qa_next                   ; not us
    cmp  edi, ecx                  ; our position <= free copies ?
    jbe  qa_yes
    jmp  qa_no
qa_next:
    inc  esi
    jmp  qa_loop
qa_yes:
    mov  eax, 1
    ret
qa_no:
    mov  eax, 0
    ret
QueueAllows ENDP

; ------------------------------------------------------------------------
; FindBook : Linear search for a book by its ID.
;     Input : eax = book ID
;     Output: eax = slot index (0..MAX_BOOKS-1) or -1 if not found.
;     Deleted (inactive) slots are skipped.  Callers test for -1.
; ------------------------------------------------------------------------
; eax = book ID -> eax = slot or -1
FindBook PROC uses ecx
    mov  ecx, 0
fb_loop:
    cmp  ecx, MAX_BOOKS
    jae  fb_none
    cmp  bookActive[ecx*4], 0   ; skip deleted slots
    je   fb_next
    cmp  bookId[ecx*4], eax   ; is this the ID we are looking for?
    je   fb_found
fb_next:
    inc  ecx
    jmp  fb_loop
fb_found:
    mov  eax, ecx
    ret
fb_none:
    mov  eax, -1   ; -1 = "not found" (callers check for it)
    ret
FindBook ENDP

; ------------------------------------------------------------------------
; FindMember : Linear search for a member by ID.
;     Input : eax = member ID
;     Output: eax = slot index or -1 if not found (inactive slots are skipped).
; ------------------------------------------------------------------------
; eax = member ID -> eax = slot or -1
FindMember PROC uses ecx
    mov  ecx, 0
fm_loop:
    cmp  ecx, MAX_MEMBERS
    jae  fm_none
    cmp  memActive[ecx*4], 0   ; skip deleted slots
    je   fm_next
    cmp  memId[ecx*4], eax   ; is this the ID we are looking for?
    je   fm_found
fm_next:
    inc  ecx
    jmp  fm_loop
fm_found:
    mov  eax, ecx
    ret
fm_none:
    mov  eax, -1   ; -1 = "not found"
    ret
FindMember ENDP

; ------------------------------------------------------------------------
; CountCurrent : How many books does this member hold right now?  Counts the member's
;     transactions that are not yet returned.  Enforces the 3-book limit.
;     Input : eax = member ID        Output: eax = count
; ------------------------------------------------------------------------
; eax = member ID -> eax = number of books currently borrowed
CountCurrent PROC uses ebx ecx
    mov  ebx, 0
    mov  ecx, 0
cc_loop:
    cmp  ecx, trCount
    jae  cc_done
    cmp  trMember[ecx*4], eax   ; is this row about our member?
    jne  cc_next
    cmp  trReturned[ecx*4], 0   ; 0 = still borrowed
    jne  cc_next
    inc  ebx   ; one more book currently held
cc_next:
    inc  ecx
    jmp  cc_loop
cc_done:
    mov  eax, ebx
    ret
CountCurrent ENDP

; ------------------------------------------------------------------------
; HasBorrowed : Does the LOGGED-IN member currently hold this book?
;     Input : eax = book ID          Output: eax = 1 (yes) or 0 (no)
;     Used to stop double-borrowing and to refuse reserving a book you hold.
; ------------------------------------------------------------------------
; eax = book ID -> eax = 1 if logged-in member currently holds it
HasBorrowed PROC uses ecx edx
    mov  edx, eax
    mov  ecx, 0
hb_loop:
    cmp  ecx, trCount
    jae  hb_no
    cmp  trBook[ecx*4], edx   ; same book?
    jne  hb_next
    mov  eax, trMember[ecx*4]
    cmp  eax, curMemId   ; same (logged-in) member?
    jne  hb_next
    cmp  trReturned[ecx*4], 0
    je   hb_yes
hb_next:
    inc  ecx
    jmp  hb_loop
hb_yes:
    mov  eax, 1
    ret
hb_no:
    mov  eax, 0
    ret
HasBorrowed ENDP

; ------------------------------------------------------------------------
; IsQueued : Is the logged-in member already waiting in the queue for this book?
;     Input : eax = book ID          Output: eax = 1 (yes) or 0 (no)
; ------------------------------------------------------------------------
; eax = book ID -> eax = 1 if logged-in member is already queued for it
IsQueued PROC uses ecx edx
    mov  edx, eax
    mov  ecx, 0
iq_loop:
    cmp  ecx, resCount
    jae  iq_no
    cmp  resBook[ecx*4], edx
    jne  iq_next
    mov  eax, resMem[ecx*4]
    cmp  eax, curMemId
    je   iq_yes
iq_next:
    inc  ecx
    jmp  iq_loop
iq_yes:
    mov  eax, 1
    ret
iq_no:
    mov  eax, 0
    ret
IsQueued ENDP

; ------------------------------------------------------------------------
; CountQueue : How many members are waiting for this book?  (queue length for one book)
;     Input : eax = book ID          Output: eax = count
; ------------------------------------------------------------------------
; eax = book ID -> eax = number of members waiting for it
CountQueue PROC uses ebx ecx
    mov  ebx, 0
    mov  ecx, 0
cq_loop:
    cmp  ecx, resCount
    jae  cq_done
    cmp  resBook[ecx*4], eax
    jne  cq_next
    inc  ebx
cq_next:
    inc  ecx
    jmp  cq_loop
cq_done:
    mov  eax, ebx
    ret
CountQueue ENDP

; ------------------------------------------------------------------------
; FirstWaiting : FIFO lookup: the first matching entry in the reservation array is the member
;     who reserved EARLIEST.
;     Input : eax = book ID          Output: eax = member ID, or 0 if nobody waits
; ------------------------------------------------------------------------
; eax = book ID -> eax = first member ID waiting (FIFO) or 0
FirstWaiting PROC uses ecx edx
    mov  edx, eax
    mov  ecx, 0
fw_loop:
    cmp  ecx, resCount
    jae  fw_none
    cmp  resBook[ecx*4], edx
    je   fw_found
    inc  ecx
    jmp  fw_loop
fw_found:
    mov  eax, resMem[ecx*4]
    ret
fw_none:
    mov  eax, 0
    ret
FirstWaiting ENDP

; ------------------------------------------------------------------------
; RemoveReservation : Dequeue by shifting: after the matching entry is found, every entry behind
;     it moves one place forward, so the FIFO order is kept, and resCount drops by 1.
;     Input : eax = member ID, edx = book ID
; ------------------------------------------------------------------------
; eax = member ID, edx = book ID : removes the first matching reservation
RemoveReservation PROC uses eax ebx ecx edx
    mov  ecx, 0
rr_loop:
    cmp  ecx, resCount
    jae  rr_done
    cmp  resMem[ecx*4], eax
    jne  rr_next
    cmp  resBook[ecx*4], edx
    je   rr_found
rr_next:
    inc  ecx
    jmp  rr_loop
rr_found:
    dec  resCount   ; queue becomes one shorter
rr_shift:
    cmp  ecx, resCount
    jae  rr_done
    mov  ebx, resMem[ecx*4+4]   ; copy the next entry one place forward
    mov  resMem[ecx*4], ebx
    mov  ebx, resBook[ecx*4+4]
    mov  resBook[ecx*4], ebx
    inc  ecx
    jmp  rr_shift
rr_done:
    ret
RemoveReservation ENDP

; ------------------------------------------------------------------------
; PushReturn : STACK push for "Recent Returns".  The newest return goes on top (index
;     retTop) and retTop is incremented.  If the stack is full (MAX_STACK) the oldest
;     entry at the bottom is dropped first by shifting everything down.
;     Input : eax = book ID, edx = member ID
; ------------------------------------------------------------------------
; eax = book ID, edx = member ID : PUSH onto the recent-returns stack
PushReturn PROC uses eax ebx ecx edx
    mov  ebx, eax
    mov  ecx, retTop
    cmp  ecx, MAX_STACK   ; is the stack full?
    jb   pr_add
    mov  ecx, 0                    ; stack full: drop the oldest entry
pr_shift:
    cmp  ecx, MAX_STACK-1
    jae  pr_shdone
    mov  eax, retStackBook[ecx*4+4]
    mov  retStackBook[ecx*4], eax
    mov  eax, retStackMem[ecx*4+4]
    mov  retStackMem[ecx*4], eax
    inc  ecx
    jmp  pr_shift
pr_shdone:
    dec  retTop
pr_add:
    mov  ecx, retTop
    mov  retStackBook[ecx*4], ebx   ; store the book on TOP of the stack
    mov  retStackMem[ecx*4], edx
    inc  retTop   ; top pointer moves up = PUSH
    ret
PushReturn ENDP

; ------------------------------------------------------------------------
; PrintBookTitle : Prints the title of a book given its ID (padded to 28 columns).  If the book was
;     deleted later, "(removed)" is shown.      Input: eax = book ID
; ------------------------------------------------------------------------
; eax = book ID : prints its title padded to 28 columns, or "(removed)"
PrintBookTitle PROC uses eax ebx edx
    call FindBook
    cmp  eax, -1
    je   pbt_none
    mov  edx, OFFSET bookName
    call StrAt
    jmp  pbt_print
pbt_none:
    mov  edx, OFFSET sRemoved
pbt_print:
    mov  ebx, 28
    call PrintPad
    ret
PrintBookTitle ENDP

; --------------------------- table printing -------------------------------
; ------------------------------------------------------------------------
; PrintBookHeader : Prints the column headings of the books table plus the dashed line below.
; ------------------------------------------------------------------------
PrintBookHeader PROC uses ebx edx
    SETCOLOR yellow
    mov  edx, OFFSET sH_ID
    call WriteString
    mov  edx, OFFSET sH_Name
    mov  ebx, 30
    call PrintPad
    mov  edx, OFFSET sH_Auth
    mov  ebx, 24
    call PrintPad
    mov  edx, OFFSET sH_Cat
    mov  ebx, 16
    call PrintPad
    mov  edx, OFFSET sH_Copy
    call WriteString
    call Crlf
    mov  edx, OFFSET sLineB
    call WriteString
    SETCOLOR lightGray
    ret
PrintBookHeader ENDP

; ------------------------------------------------------------------------
; PrintBookRow : Prints one book as a table row (ID, name, author, category, copies, borrows).
;     Input : eax = book slot index
; ------------------------------------------------------------------------
; eax = book slot : prints one row
PrintBookRow PROC uses eax ebx ecx edx
    mov  ecx, eax
    mov  eax, bookId[ecx*4]
    call WriteDec
    mov  al, 9
    call WriteChar
    mov  edx, OFFSET bookName
    mov  eax, ecx
    call StrAt
    mov  ebx, 30
    call PrintPad
    mov  edx, OFFSET bookAuthor
    mov  eax, ecx
    call StrAt
    mov  ebx, 24
    call PrintPad
    mov  edx, OFFSET bookCat
    mov  eax, ecx
    call StrAt
    mov  ebx, 16
    call PrintPad
    mov  eax, bookCopies[ecx*4]
    mov  ebx, 8
    call PrintNumPad
    mov  eax, bookBorrowCnt[ecx*4]
    call WriteDec
    call Crlf
    ret
PrintBookRow ENDP

; ------------------------------------------------------------------------
; PrintMemberHeader : Prints the column headings of the members table plus the dashed line.
; ------------------------------------------------------------------------
PrintMemberHeader PROC uses ebx edx
    SETCOLOR yellow
    mov  edx, OFFSET sH_ID
    call WriteString
    mov  edx, OFFSET sH_Name
    mov  ebx, 30
    call PrintPad
    mov  edx, OFFSET sH_Bor
    call WriteString
    call Crlf
    mov  edx, OFFSET sLineS
    call WriteString
    SETCOLOR lightGray
    ret
PrintMemberHeader ENDP

; ------------------------------------------------------------------------
; PrintMemberRow : Prints one member as a table row (ID, name, total borrowed, fine).
;     Input : eax = member slot index
; ------------------------------------------------------------------------
; eax = member slot : prints one row
PrintMemberRow PROC uses eax ebx ecx edx
    mov  ecx, eax
    mov  eax, memId[ecx*4]
    call WriteDec
    mov  al, 9
    call WriteChar
    mov  edx, OFFSET memName
    mov  eax, ecx
    call StrAt
    mov  ebx, 30
    call PrintPad
    mov  eax, memBorrowTotal[ecx*4]
    mov  ebx, 10
    call PrintNumPad
    mov  eax, memFine[ecx*4]
    call WriteDec
    call Crlf
    ret
PrintMemberRow ENDP

; ------------------------------------------------------------------------
; ListTrans : Prints transactions filtered by two global switches (set by the caller):
;       fMode : 0 = all, 1 = only returned, 2 = only not yet returned
;       fMem  : 0 = every member, otherwise only that member ID
;     Admin "Transaction Records", "Member History" and "My History" all reuse this
;     one procedure.  The Returned/Issued status is decided from trReturned[].
; ------------------------------------------------------------------------
; Lists transactions filtered by fMode / fMem
ListTrans PROC uses eax ebx ecx edx
    SETCOLOR yellow
    mov  edx, OFFSET sH_Mem
    call WriteString
    mov  edx, OFFSET sH_Book
    call WriteString
    mov  edx, OFFSET sH_Title
    mov  ebx, 28
    call PrintPad
    mov  edx, OFFSET sH_Stat
    mov  ebx, 12
    call PrintPad
    mov  edx, OFFSET sH_Fine
    call WriteString
    call Crlf
    mov  edx, OFFSET sLineS
    call WriteString
    SETCOLOR lightGray
    mov  dispCnt, 0
    mov  ecx, 0
lt_loop:
    cmp  ecx, trCount
    jae  lt_end
    cmp  fMem, 0
    je   lt_mode
    mov  eax, trMember[ecx*4]
    cmp  eax, fMem
    jne  lt_next
lt_mode:
    mov  eax, trReturned[ecx*4]
    cmp  fMode, 1
    jne  lt_m2
    cmp  eax, 1
    jne  lt_next
    jmp  lt_print
lt_m2:
    cmp  fMode, 2
    jne  lt_print
    cmp  eax, 0
    jne  lt_next
lt_print:
    inc  dispCnt
    mov  eax, trMember[ecx*4]
    call WriteDec
    mov  al, 9
    call WriteChar
    mov  eax, trBook[ecx*4]
    call WriteDec
    mov  al, 9
    call WriteChar
    mov  eax, trBook[ecx*4]
    call PrintBookTitle
    cmp  trReturned[ecx*4], 0
    jne  lt_isret
    mov  edx, OFFSET sIssued
    jmp  lt_stat
lt_isret:
    mov  edx, OFFSET sReturned
lt_stat:
    mov  ebx, 12
    call PrintPad
    mov  eax, trFine[ecx*4]
    call WriteDec
    call Crlf
lt_next:
    inc  ecx
    jmp  lt_loop
lt_end:
    cmp  dispCnt, 0
    jne  lt_ok
    mov  edx, OFFSET sNoRecords
    call WriteString
lt_ok:
    ret
ListTrans ENDP

; --------------------------- sorting / maximum ----------------------------
; ------------------------------------------------------------------------
; SortIdx : BUBBLE SORT on an index list.  The real records are never moved.  We build a
;     list of the active slot numbers (sortList) and sort THAT list by the matching
;     value array, so one routine sorts books (by borrow count) and members (by
;     books borrowed).
;     Input : esi = value array, edi = active-flag array, ecx = number of slots,
;             edx = 1 for highest-to-lowest, 0 for lowest-to-highest
;     Output: sortList[0..sortN-1] = slot numbers in sorted order
;     Bubble sort: n-1 passes; in each pass neighbours are compared and swapped
;     when they are in the wrong order.
; ------------------------------------------------------------------------
; esi = values array, edi = active-flags array, ecx = slots, edx = 1 desc / 0 asc
; builds sortList[] (slot numbers) and sortN, bubble sorted by value
SortIdx PROC uses eax ebx ecx
    mov  sortN, 0   ; number of active records found
    mov  ebx, 0
si_build:
    cmp  ebx, ecx
    jae  si_built
    cmp  DWORD PTR [edi+ebx*4], 0   ; only active records take part in the sort
    je   si_nb
    mov  eax, sortN
    mov  sortList[eax*4], ebx   ; append this slot number to the list
    inc  sortN
si_nb:
    inc  ebx
    jmp  si_build
si_built:
    mov  ecx, sortN
    cmp  ecx, 2
    jb   si_done
    dec  ecx   ; n records need n-1 passes
    mov  sortLim, ecx
si_outer:
    mov  ebx, 0
si_inner:
    mov  eax, sortList[ebx*4]
    mov  eax, [esi+eax*4]   ; value of the first neighbour
    mov  tmpA, eax
    mov  eax, sortList[ebx*4+4]
    mov  eax, [esi+eax*4]
    cmp  edx, 1
    je   si_desc
    cmp  tmpA, eax
    jle  si_noswap
    jmp  si_swap
si_desc:
    cmp  tmpA, eax
    jge  si_noswap
si_swap:
    mov  eax, sortList[ebx*4]
    xchg eax, sortList[ebx*4+4]   ; swap the two neighbours in the list
    mov  sortList[ebx*4], eax
si_noswap:
    inc  ebx
    cmp  ebx, sortLim
    jb   si_inner
    loop si_outer
si_done:
    ret
SortIdx ENDP

; ------------------------------------------------------------------------
; FindMaxIdx : Finds the slot with the biggest value (strictly greater than 0).
;     Input : esi = value array, edi = active flags, ecx = slots
;     Output: eax = best slot (-1 if every value is 0), edx = that value
;     Used for "Most Borrowed Book" and "Top Reader".
; ------------------------------------------------------------------------
; esi = values, edi = active flags, ecx = slots -> eax = best slot (-1 if none >0), edx = value
FindMaxIdx PROC uses ebx ecx
    mov  eax, -1
    mov  edx, 0
    mov  ebx, 0
fx_loop:
    cmp  ebx, ecx
    jae  fx_done
    cmp  DWORD PTR [edi+ebx*4], 0
    je   fx_next
    cmp  [esi+ebx*4], edx
    jle  fx_next
    mov  edx, [esi+ebx*4]
    mov  eax, ebx
fx_next:
    inc  ebx
    jmp  fx_loop
fx_done:
    ret
FindMaxIdx ENDP

; ------------------------------------------------------------------------
; ShowTop : Prints one statistics line: label, name of the winning record, and its count.
;     Input : edx = label, ebx = name table, eax = slot (-1 = none), ecx = value
; ------------------------------------------------------------------------
; edx = label, ebx = name table, eax = slot (-1 = none), ecx = value
ShowTop PROC uses eax ecx edx
    SETCOLOR lightCyan
    call WriteString
    SETCOLOR yellow
    cmp  eax, -1
    je   stp_na
    mov  edx, ebx
    call StrAt
    call WriteString
    mov  edx, OFFSET sParenO
    call WriteString
    mov  eax, ecx
    call WriteDec
    mov  edx, OFFSET sParenC
    call WriteString
    SETCOLOR lightGray
    ret
stp_na:
    mov  edx, OFFSET sNA
    call WriteString
    SETCOLOR lightGray
    ret
ShowTop ENDP

; ==========================================================================
;                               LOGIN SYSTEM
; ==========================================================================
; ------------------------------------------------------------------------
; AdminLogin : Admin authentication.  Reads username and password and compares each with the
;     stored text using Str_compare (ZF = 1 when the strings are equal).  Both must
;     match.   Returns eax = 1 on success, 0 on failure (error message box shown).
; ------------------------------------------------------------------------
AdminLogin PROC
    call Clrscr
    mov  edx, OFFSET sAdminTitle
    call PrintTitle
    mov  edx, OFFSET sUser
    call WriteString
    mov  edx, OFFSET inBuf
    mov  ecx, 30
    call ReadString
    mov  edx, OFFSET sPass
    call WriteString
    mov  edx, OFFSET inBuf2
    mov  ecx, 30
    call ReadString
    INVOKE Str_compare, ADDR inBuf, ADDR adminUser   ; ZF = 1 when the username matches
    jne  al_fail
    INVOKE Str_compare, ADDR inBuf2, ADDR adminPass
    jne  al_fail
    mov  eax, 1
    ret
al_fail:
    mov  edx, OFFSET msgLoginErr
    call ErrBox
    mov  eax, 0
    ret
AdminLogin ENDP

; ------------------------------------------------------------------------
; MemberLogin : Member authentication: (1) search the member by ID with FindMember,
;     (2) compare the typed PIN with the stored PIN.  On success the member's slot
;     (curMember) and ID (curMemId) are remembered - every member function uses
;     them.   Returns eax = 1 on success, 0 on failure.
; ------------------------------------------------------------------------
MemberLogin PROC
    call Clrscr
    mov  edx, OFFSET sMemberTitle
    call PrintTitle
    mov  edx, OFFSET sMemId
    call WriteString
    call ReadInt
    mov  tmpId, eax
    mov  edx, OFFSET sMemPin
    call WriteString
    call ReadInt
    mov  tmpA, eax                 ; entered PIN
    mov  eax, tmpId
    call FindMember
    cmp  eax, -1
    je   ml_fail
    mov  ebx, memPin[eax*4]   ; PIN stored for this member
    cmp  ebx, tmpA   ; compare with the PIN that was typed
    jne  ml_fail
    mov  curMember, eax
    mov  ebx, memId[eax*4]
    mov  curMemId, ebx
    mov  eax, 1
    ret
ml_fail:
    mov  edx, OFFSET msgLoginErr
    call ErrBox
    mov  eax, 0
    ret
MemberLogin ENDP

; ==========================================================================
;                              ADMIN PANEL
; ==========================================================================
; ------------------------------------------------------------------------
; AdminMenu : Admin panel menu loop (a manual switch): read choice, jump to the matching
;     sub-menu, return here, repeat until Logout.
; ------------------------------------------------------------------------
AdminMenu PROC
am_loop:
    call Clrscr
    mov  edx, OFFSET sAdminMenuT
    call PrintTitle
    mov  edx, OFFSET sAdminMenu
    call PrintMenu
    call ReadInt
    cmp  eax, 1
    je   am_book
    cmp  eax, 2
    je   am_mem
    cmp  eax, 3
    je   am_trans
    cmp  eax, 4
    je   am_recent
    cmp  eax, 5
    je   am_stats
    cmp  eax, 6
    je   am_exit
    jmp  am_loop
am_book:
    call BookMenu
    jmp  am_loop
am_mem:
    call MemberAdminMenu
    jmp  am_loop
am_trans:
    call TransMenu
    jmp  am_loop
am_recent:
    call RecentMenu
    jmp  am_loop
am_stats:
    call ShowStats
    jmp  am_loop
am_exit:
    ret
AdminMenu ENDP

; ------------------------------ 2.1 BOOKS ---------------------------------
; ------------------------------------------------------------------------
; BookMenu : 2.1 Book Management menu loop.
; ------------------------------------------------------------------------
BookMenu PROC
bm_loop:
    call Clrscr
    mov  edx, OFFSET sBookMenuT
    call PrintTitle
    mov  edx, OFFSET sBookMenu
    call PrintMenu
    call ReadInt
    cmp  eax, 1
    je   bm_add
    cmp  eax, 2
    je   bm_rem
    cmp  eax, 3
    je   bm_all
    cmp  eax, 4
    je   bm_srch
    cmp  eax, 5
    je   bm_sort
    cmp  eax, 6
    je   bm_exit
    jmp  bm_loop
bm_add:
    call AddBook
    jmp  bm_loop
bm_rem:
    call RemoveBook
    jmp  bm_loop
bm_all:
    call ShowAllBooks
    jmp  bm_loop
bm_srch:
    call SearchBook
    jmp  bm_loop
bm_sort:
    call SortBooksMenu
    jmp  bm_loop
bm_exit:
    ret
BookMenu ENDP

; ------------------------------------------------------------------------
; AddBook : Add Book.  Steps: validate the ID (> 0 and not already used), find the first
;     free slot, read name / author / category into that slot, read the copies,
;     and ONLY THEN mark the slot active.  If any input is invalid the procedure
;     leaves, so no half-created record is ever visible.
; ------------------------------------------------------------------------
AddBook PROC
    call Clrscr
    mov  edx, OFFSET sTAddBook
    call PrintTitle
    mov  edx, OFFSET sPBookId
    call WriteString
    call ReadInt
    cmp  eax, 0
    jle  ab_invalid
    mov  tmpId, eax
    call FindBook   ; duplicate-ID check (found = error)
    cmp  eax, -1
    jne  ab_dup
    mov  ecx, 0                    ; find a free slot
ab_slot:
    cmp  ecx, MAX_BOOKS
    jae  ab_full
    cmp  bookActive[ecx*4], 0   ; first free slot
    je   ab_got
    inc  ecx
    jmp  ab_slot
ab_got:
    mov  tmpSlot, ecx
    mov  edx, OFFSET sPBookName
    call WriteString
    mov  edx, OFFSET bookName
    mov  eax, tmpSlot
    call StrAt
    call GetName
    mov  edx, OFFSET sPAuthor
    call WriteString
    mov  edx, OFFSET bookAuthor
    mov  eax, tmpSlot
    call StrAt
    call GetName
    mov  edx, OFFSET sPCat
    call WriteString
    mov  edx, OFFSET bookCat
    mov  eax, tmpSlot
    call StrAt
    call GetName
    mov  edx, OFFSET sPCopies
    call WriteString
    call ReadInt
    cmp  eax, 0
    jle  ab_invalid
    mov  ecx, tmpSlot
    mov  bookCopies[ecx*4], eax
    mov  eax, tmpId
    mov  bookId[ecx*4], eax
    mov  bookBorrowCnt[ecx*4], 0
    mov  bookActive[ecx*4], 1   ; activate the record only now - all input was valid
    mov  edx, OFFSET msgBookAdded
    call InfoBox
    ret
ab_dup:
    mov  edx, OFFSET msgBookDup
    call ErrBox
    ret
ab_full:
    mov  edx, OFFSET msgBookFull
    call ErrBox
    ret
ab_invalid:
    mov  edx, OFFSET msgInvalid
    call ErrBox
    ret
AddBook ENDP

; ------------------------------------------------------------------------
; RemoveBook : Remove Book.  Search by ID (error box if absent), ask Yes/No, and only on Yes
;     perform a soft delete (bookActive = 0).  The slot becomes free for re-use.
; ------------------------------------------------------------------------
RemoveBook PROC
    call Clrscr
    mov  edx, OFFSET sTRemBook
    call PrintTitle
    mov  edx, OFFSET sPBookId
    call WriteString
    call ReadInt
    call FindBook
    cmp  eax, -1
    je   rb_nf
    mov  tmpSlot, eax
    mov  edx, OFFSET msgDelBookQ
    call AskBox
    cmp  eax, 6
    jne  rb_cancel
    mov  ebx, tmpSlot
    mov  bookActive[ebx*4], 0   ; soft delete
    mov  edx, OFFSET msgBookGone
    call InfoBox
rb_cancel:
    ret
rb_nf:
    mov  edx, OFFSET msgNoBook
    call ErrBox
    ret
RemoveBook ENDP

; ------------------------------------------------------------------------
; ShowAllBooks : Display all books: header, then one row for every active slot.
; ------------------------------------------------------------------------
ShowAllBooks PROC uses eax ecx edx
    call Clrscr
    mov  edx, OFFSET sTAllBooks
    call PrintTitle
    call PrintBookHeader
    mov  dispCnt, 0
    mov  ecx, 0
sa_loop:
    cmp  ecx, MAX_BOOKS
    jae  sa_end
    cmp  bookActive[ecx*4], 0
    je   sa_next
    inc  dispCnt
    mov  eax, ecx
    call PrintBookRow
sa_next:
    inc  ecx
    jmp  sa_loop
sa_end:
    cmp  dispCnt, 0
    jne  sa_wait
    mov  edx, OFFSET sNoRecords
    call WriteString
sa_wait:
    call Crlf
    call WaitMsg
    ret
ShowAllBooks ENDP

; ------------------------------------------------------------------------
; SearchBook : Search a book by ID and display its details (shared by Admin and Member).
; ------------------------------------------------------------------------
SearchBook PROC
    call Clrscr
    mov  edx, OFFSET sTSrchBook
    call PrintTitle
    mov  edx, OFFSET sPBookId
    call WriteString
    call ReadInt
    call FindBook
    cmp  eax, -1
    je   sb_nf
    mov  tmpSlot, eax
    call Crlf
    call PrintBookHeader
    mov  eax, tmpSlot
    call PrintBookRow
    call Crlf
    call WaitMsg
    ret
sb_nf:
    mov  edx, OFFSET msgNoBook
    call ErrBox
    ret
SearchBook ENDP

; ------------------------------------------------------------------------
; SortBooksMenu : Sort books by borrow count.  Choice 1 = highest to lowest, 2 = lowest to
;     highest.  SortIdx produces the sorted slot list, which is then printed.
; ------------------------------------------------------------------------
SortBooksMenu PROC
    call Clrscr
    mov  edx, OFFSET sSortMenuT
    call PrintTitle
    mov  edx, OFFSET sSortMenu
    call PrintMenu
    call ReadInt
    cmp  eax, 1
    je   sm_desc
    cmp  eax, 2
    je   sm_asc
    ret
sm_desc:
    mov  edx, 1
    jmp  sm_go
sm_asc:
    mov  edx, 0
sm_go:
    mov  esi, OFFSET bookBorrowCnt
    mov  edi, OFFSET bookActive
    mov  ecx, MAX_BOOKS
    call SortIdx
    call Clrscr
    mov  edx, OFFSET sTSorted
    call PrintTitle
    call PrintBookHeader
    mov  ecx, 0
sm_print:
    cmp  ecx, sortN
    jae  sm_done
    mov  eax, sortList[ecx*4]
    call PrintBookRow
    inc  ecx
    jmp  sm_print
sm_done:
    call Crlf
    call WaitMsg
    ret
SortBooksMenu ENDP

; ----------------------------- 2.2 MEMBERS --------------------------------
; ------------------------------------------------------------------------
; MemberAdminMenu : 2.2 Member Management menu loop.
; ------------------------------------------------------------------------
MemberAdminMenu PROC
mm_loop:
    call Clrscr
    mov  edx, OFFSET sMemMenuT
    call PrintTitle
    mov  edx, OFFSET sMemMenu
    call PrintMenu
    call ReadInt
    cmp  eax, 1
    je   mm_add
    cmp  eax, 2
    je   mm_rem
    cmp  eax, 3
    je   mm_srch
    cmp  eax, 4
    je   mm_all
    cmp  eax, 5
    je   mm_hist
    cmp  eax, 6
    je   mm_rank
    cmp  eax, 7
    je   mm_exit
    jmp  mm_loop
mm_add:
    call AddMember
    jmp  mm_loop
mm_rem:
    call RemoveMember
    jmp  mm_loop
mm_srch:
    call SearchMember
    jmp  mm_loop
mm_all:
    call ShowAllMembers
    jmp  mm_loop
mm_hist:
    call MemberHistory
    jmp  mm_loop
mm_rank:
    call MemberRanking
    jmp  mm_loop
mm_exit:
    ret
MemberAdminMenu ENDP

; ------------------------------------------------------------------------
; AddMember : Add Member.  The member ID is GENERATED from the counter nextMemberId (starts
;     at 1001 and increases by 1), so IDs are always unique.  The new ID is shown in
;     the success message box (message built in msgBuf with AppendStr/AppendNum).
; ------------------------------------------------------------------------
AddMember PROC
    call Clrscr
    mov  edx, OFFSET sTAddMem
    call PrintTitle
    mov  ecx, 0
am2_slot:
    cmp  ecx, MAX_MEMBERS
    jae  am2_full
    cmp  memActive[ecx*4], 0
    je   am2_got
    inc  ecx
    jmp  am2_slot
am2_got:
    mov  tmpSlot, ecx
    mov  edx, OFFSET sPMemName
    call WriteString
    mov  edx, OFFSET memName
    mov  eax, tmpSlot
    call StrAt
    call GetName
    mov  edx, OFFSET sPMemPin
    call WriteString
    call ReadInt
    cmp  eax, 0
    jle  am2_invalid
    mov  ecx, tmpSlot
    mov  memPin[ecx*4], eax
    mov  eax, nextMemberId                 ; Generate Member ID
    mov  memId[ecx*4], eax
    inc  nextMemberId   ; next member gets the next number
    mov  memBorrowTotal[ecx*4], 0
    mov  memFine[ecx*4], 0
    mov  memActive[ecx*4], 1
    mov  edi, OFFSET msgBuf
    mov  esi, OFFSET msgMemOk
    call AppendStr
    mov  eax, memId[ecx*4]
    call AppendNum
    mov  edx, OFFSET msgBuf
    call InfoBox
    ret
am2_full:
    mov  edx, OFFSET msgMemFull
    call ErrBox
    ret
am2_invalid:
    mov  edx, OFFSET msgInvalid
    call ErrBox
    ret
AddMember ENDP

; ------------------------------------------------------------------------
; RemoveMember : Remove Member: search by ID, ask Yes/No, then soft delete (memActive = 0).
; ------------------------------------------------------------------------
RemoveMember PROC
    call Clrscr
    mov  edx, OFFSET sTRemMem
    call PrintTitle
    mov  edx, OFFSET sPMemId
    call WriteString
    call ReadInt
    call FindMember
    cmp  eax, -1
    je   rm_nf
    mov  tmpSlot, eax
    mov  edx, OFFSET msgDelMemQ
    call AskBox
    cmp  eax, 6
    jne  rm_cancel
    mov  ebx, tmpSlot
    mov  memActive[ebx*4], 0
    mov  edx, OFFSET msgMemGone
    call InfoBox
rm_cancel:
    ret
rm_nf:
    mov  edx, OFFSET msgNoMember
    call ErrBox
    ret
RemoveMember ENDP

; ------------------------------------------------------------------------
; SearchMember : Search a member by ID and display the details.
; ------------------------------------------------------------------------
SearchMember PROC
    call Clrscr
    mov  edx, OFFSET sTSrchMem
    call PrintTitle
    mov  edx, OFFSET sPMemId
    call WriteString
    call ReadInt
    call FindMember
    cmp  eax, -1
    je   sm2_nf
    mov  tmpSlot, eax
    call Crlf
    call PrintMemberHeader
    mov  eax, tmpSlot
    call PrintMemberRow
    call Crlf
    call WaitMsg
    ret
sm2_nf:
    mov  edx, OFFSET msgNoMember
    call ErrBox
    ret
SearchMember ENDP

; ------------------------------------------------------------------------
; ShowAllMembers : Display all active members.
; ------------------------------------------------------------------------
ShowAllMembers PROC uses eax ecx edx
    call Clrscr
    mov  edx, OFFSET sTAllMem
    call PrintTitle
    call PrintMemberHeader
    mov  dispCnt, 0
    mov  ecx, 0
sam_loop:
    cmp  ecx, MAX_MEMBERS
    jae  sam_end
    cmp  memActive[ecx*4], 0
    je   sam_next
    inc  dispCnt
    mov  eax, ecx
    call PrintMemberRow
sam_next:
    inc  ecx
    jmp  sam_loop
sam_end:
    cmp  dispCnt, 0
    jne  sam_wait
    mov  edx, OFFSET sNoRecords
    call WriteString
sam_wait:
    call Crlf
    call WaitMsg
    ret
ShowAllMembers ENDP

; ------------------------------------------------------------------------
; MemberHistory : View Member History (admin).  Uses ListTrans with fMem = that member's ID and
;     fMode = 0, which prints every book the member borrowed / returned.
; ------------------------------------------------------------------------
MemberHistory PROC
    call Clrscr
    mov  edx, OFFSET sTHist
    call PrintTitle
    mov  edx, OFFSET sPMemId
    call WriteString
    call ReadInt
    mov  tmpId, eax
    call FindMember
    cmp  eax, -1
    je   mh_nf
    call Crlf
    mov  eax, tmpId
    mov  fMem, eax
    mov  fMode, 0
    call ListTrans
    mov  fMem, 0
    call Crlf
    call WaitMsg
    ret
mh_nf:
    mov  edx, OFFSET msgNoMember
    call ErrBox
    ret
MemberHistory ENDP

; ------------------------------------------------------------------------
; MemberRanking : Member Ranking: members sorted by books borrowed (highest first) using
;     SortIdx, printed with a rank number 1, 2, 3 ...
; ------------------------------------------------------------------------
MemberRanking PROC
    call Clrscr
    mov  edx, OFFSET sTRank
    call PrintTitle
    mov  esi, OFFSET memBorrowTotal
    mov  edi, OFFSET memActive
    mov  ecx, MAX_MEMBERS
    mov  edx, 1
    call SortIdx
    SETCOLOR yellow
    mov  edx, OFFSET sH_Rank
    call WriteString
    call PrintMemberHeader
    mov  ecx, 0
mr_loop:
    cmp  ecx, sortN
    jae  mr_done
    mov  eax, ecx
    inc  eax
    call WriteDec
    mov  al, 9
    call WriteChar
    mov  eax, sortList[ecx*4]
    call PrintMemberRow
    inc  ecx
    jmp  mr_loop
mr_done:
    call Crlf
    call WaitMsg
    ret
MemberRanking ENDP

; ------------------------ 2.3 TRANSACTION RECORDS -------------------------
; ------------------------------------------------------------------------
; TransMenu : 2.3 Transaction Records.  Only sets the filter (fMode) and calls ListTrans:
;     all records / returned only / current borrowers (not returned) / fines.
; ------------------------------------------------------------------------
TransMenu PROC
tm_loop:
    call Clrscr
    mov  edx, OFFSET sTransMenuT
    call PrintTitle
    mov  edx, OFFSET sTransMenu
    call PrintMenu
    call ReadInt
    cmp  eax, 1
    je   tm_all
    cmp  eax, 2
    je   tm_ret
    cmp  eax, 3
    je   tm_cur
    cmp  eax, 4
    je   tm_fine
    cmp  eax, 5
    je   tm_exit
    jmp  tm_loop
tm_all:
    mov  fMode, 0
    jmp  tm_show
tm_ret:
    mov  fMode, 1
    jmp  tm_show
tm_cur:
    mov  fMode, 2
tm_show:
    call Clrscr
    mov  edx, OFFSET sTTrans
    call PrintTitle
    mov  fMem, 0
    call ListTrans
    call Crlf
    call WaitMsg
    jmp  tm_loop
tm_fine:
    call ShowFines
    jmp  tm_loop
tm_exit:
    ret
TransMenu ENDP

; ------------------------------------------------------------------------
; ShowFines : Lists every member whose outstanding fine is greater than 0.
; ------------------------------------------------------------------------
ShowFines PROC uses eax ecx edx
    call Clrscr
    mov  edx, OFFSET sTFines
    call PrintTitle
    call PrintMemberHeader
    mov  dispCnt, 0
    mov  ecx, 0
sf_loop:
    cmp  ecx, MAX_MEMBERS
    jae  sf_end
    cmp  memActive[ecx*4], 0
    je   sf_next
    cmp  memFine[ecx*4], 0
    jle  sf_next
    inc  dispCnt
    mov  eax, ecx
    call PrintMemberRow
sf_next:
    inc  ecx
    jmp  sf_loop
sf_end:
    cmp  dispCnt, 0
    jne  sf_wait
    mov  edx, OFFSET sNoRecords
    call WriteString
sf_wait:
    call Crlf
    call WaitMsg
    ret
ShowFines ENDP

; ------------------------ 2.4 RECENT RETURNS (STACK) ----------------------
; PrintReturnHeader : yellow column headings and dashed line for the
;     Recent Returns screens (same style as the other tables).
PrintReturnHeader PROC uses edx
    SETCOLOR yellow
    mov  edx, OFFSET sH_Mem
    call WriteString
    mov  edx, OFFSET sH_Book
    call WriteString
    mov  edx, OFFSET sH_Title
    call WriteString
    call Crlf
    mov  edx, OFFSET sLineS
    call WriteString
    SETCOLOR lightGray
    ret
PrintReturnHeader ENDP

; ------------------------------------------------------------------------
; RecentMenu : 2.4 Recent Returns - the STACK (LIFO) in action:
;       View Most Recent Return = PEEK (read index retTop-1)
;       View Recent Returns     = print from the top (retTop-1) down to 0
;       Remove Top Return       = POP (retTop = retTop - 1)
; ------------------------------------------------------------------------
RecentMenu PROC
rm2_loop:
    call Clrscr
    mov  edx, OFFSET sRecentMenuT
    call PrintTitle
    mov  edx, OFFSET sRecentMenu
    call PrintMenu
    call ReadInt
    cmp  eax, 1
    je   rm2_peek
    cmp  eax, 2
    je   rm2_all
    cmp  eax, 3
    je   rm2_pop
    cmp  eax, 4
    je   rm2_exit
    jmp  rm2_loop
rm2_peek:
    call Clrscr
    cmp  retTop, 0
    je   rm2_empty
    mov  edx, OFFSET sTRecentOne
    call PrintTitle
    call PrintReturnHeader
    mov  ecx, retTop
    dec  ecx
    mov  eax, retStackMem[ecx*4]
    call WriteDec
    mov  al, 9
    call WriteChar
    mov  eax, retStackBook[ecx*4]
    call WriteDec
    mov  al, 9
    call WriteChar
    mov  eax, retStackBook[ecx*4]
    call PrintBookTitle
    call Crlf
    call Crlf
    call WaitMsg
    jmp  rm2_loop
rm2_all:
    call Clrscr
    mov  edx, OFFSET sTRecent
    call PrintTitle
    cmp  retTop, 0
    je   rm2_empty
    call PrintReturnHeader
    mov  ecx, retTop
rm2_l:
    cmp  ecx, 0
    je   rm2_ld
    dec  ecx
    mov  eax, retStackMem[ecx*4]
    call WriteDec
    mov  al, 9
    call WriteChar
    mov  eax, retStackBook[ecx*4]
    call WriteDec
    mov  al, 9
    call WriteChar
    mov  eax, retStackBook[ecx*4]
    call PrintBookTitle
    call Crlf
    jmp  rm2_l
rm2_ld:
    call Crlf
    call WaitMsg
    jmp  rm2_loop
rm2_pop:
    cmp  retTop, 0
    je   rm2_empty
    dec  retTop                          ; POP (LIFO)
    mov  edx, OFFSET msgPopped
    call InfoBox
    jmp  rm2_loop
rm2_empty:
    mov  edx, OFFSET msgNoRet
    call WarnBox
    jmp  rm2_loop
rm2_exit:
    ret
RecentMenu ENDP

; ----------------------------- 2.5 STATISTICS -----------------------------
; ------------------------------------------------------------------------
; ShowStats : 2.5 Statistics.  Totals are simple counting loops.  Most borrowed book and top
;     reader use FindMaxIdx.  Most popular category: for every book, add up the
;     borrow counts of all books that have the SAME category (nested loop with
;     StrCompareI) and keep the category with the largest sum.
; ------------------------------------------------------------------------
ShowStats PROC uses eax ebx ecx edx esi edi
    call Clrscr
    mov  edx, OFFSET sTStats
    call PrintTitle
    ; total books and available copies
    mov  esi, 0
    mov  edi, 0
    mov  ecx, 0
ss_b:
    cmp  ecx, MAX_BOOKS
    jae  ss_bd
    cmp  bookActive[ecx*4], 0
    je   ss_bn
    inc  esi
    add  edi, bookCopies[ecx*4]
ss_bn:
    inc  ecx
    jmp  ss_b
ss_bd:
    mov  eax, esi
    mov  edx, OFFSET sStTB
    call PrintLabelNum
    ; total members
    mov  esi, 0
    mov  ecx, 0
ss_m:
    cmp  ecx, MAX_MEMBERS
    jae  ss_md
    cmp  memActive[ecx*4], 0
    je   ss_mn
    inc  esi
ss_mn:
    inc  ecx
    jmp  ss_m
ss_md:
    mov  eax, esi
    mov  edx, OFFSET sStTM
    call PrintLabelNum
    mov  eax, edi
    mov  edx, OFFSET sStAvail
    call PrintLabelNum
    ; currently borrowed
    mov  esi, 0
    mov  ecx, 0
ss_t:
    cmp  ecx, trCount
    jae  ss_td
    cmp  trReturned[ecx*4], 0
    jne  ss_tn
    inc  esi
ss_tn:
    inc  ecx
    jmp  ss_t
ss_td:
    mov  eax, esi
    mov  edx, OFFSET sStBorrowed
    call PrintLabelNum
    ; most borrowed book
    mov  esi, OFFSET bookBorrowCnt
    mov  edi, OFFSET bookActive
    mov  ecx, MAX_BOOKS
    call FindMaxIdx   ; best slot -> eax, its value -> edx
    mov  ecx, edx
    mov  ebx, OFFSET bookName
    mov  edx, OFFSET sStMostBook
    call ShowTop
    ; top reader
    mov  esi, OFFSET memBorrowTotal
    mov  edi, OFFSET memActive
    mov  ecx, MAX_MEMBERS
    call FindMaxIdx
    mov  ecx, edx
    mov  ebx, OFFSET memName
    mov  edx, OFFSET sStTopReader
    call ShowTop
    ; most popular category (sum of borrow counts per category)
    mov  catBestSlot, -1
    mov  catBestScore, 0
    mov  catI, 0
sc_i:
    cmp  catI, MAX_BOOKS
    jae  sc_id
    mov  ebx, catI
    cmp  bookActive[ebx*4], 0
    je   sc_in
    mov  catSum, 0
    mov  catJ, 0
sc_j:
    cmp  catJ, MAX_BOOKS
    jae  sc_jd
    mov  ebx, catJ
    cmp  bookActive[ebx*4], 0
    je   sc_jn
    mov  edx, OFFSET bookCat
    mov  eax, catI
    call StrAt
    mov  ptr1, edx
    mov  edx, OFFSET bookCat
    mov  eax, catJ
    call StrAt
    mov  ptr2, edx
    mov  esi, ptr1                         ; case-insensitive compare of two categories
    mov  edi, ptr2
    call StrCompareI
    jne  sc_jn
    mov  ebx, catJ
    mov  eax, bookBorrowCnt[ebx*4]
    add  catSum, eax
sc_jn:
    inc  catJ
    jmp  sc_j
sc_jd:
    mov  eax, catSum
    cmp  eax, catBestScore
    jle  sc_in
    mov  catBestScore, eax
    mov  eax, catI
    mov  catBestSlot, eax
sc_in:
    inc  catI
    jmp  sc_i
sc_id:
    mov  eax, catBestSlot
    mov  ecx, catBestScore
    mov  ebx, OFFSET bookCat
    mov  edx, OFFSET sStPopCat
    call ShowTop
    call Crlf
    call WaitMsg
    ret
ShowStats ENDP

; ==========================================================================
;                              MEMBER PANEL
; ==========================================================================
; ------------------------------------------------------------------------
; MemberMenu : 3. Member panel menu loop (shown after a successful member login).
; ------------------------------------------------------------------------
MemberMenu PROC
mp_loop:
    call Clrscr
    SETCOLOR lightGreen
    mov  edx, OFFSET sWelcome
    call WriteString
    mov  edx, OFFSET memName
    mov  eax, curMember
    call StrAt
    call WriteString
    call Crlf
    SETCOLOR lightGray
    mov  edx, OFFSET sMemberMenuT
    call PrintTitle
    mov  edx, OFFSET sMemberMenu
    call PrintMenu
    call ReadInt
    cmp  eax, 1
    je   mp_view
    cmp  eax, 2
    je   mp_search
    cmp  eax, 3
    je   mp_borrow
    cmp  eax, 4
    je   mp_return
    cmp  eax, 5
    je   mp_reserve
    cmp  eax, 6
    je   mp_hist
    cmp  eax, 7
    je   mp_rec
    cmp  eax, 8
    je   mp_pay
    cmp  eax, 9
    je   mp_exit
    jmp  mp_loop
mp_view:
    call ShowAllBooks
    jmp  mp_loop
mp_search:
    call SearchBook
    jmp  mp_loop
mp_borrow:
    call BorrowBook
    jmp  mp_loop
mp_return:
    call ReturnBook
    jmp  mp_loop
mp_reserve:
    call ReserveBook
    jmp  mp_loop
mp_hist:
    call MyHistory
    jmp  mp_loop
mp_rec:
    call Recommend
    jmp  mp_loop
mp_pay:
    call PayFine
    jmp  mp_loop
mp_exit:
    ret
MemberMenu ENDP

; ------------------------------ 3.3 BORROW --------------------------------
; ------------------------------------------------------------------------
; BorrowBook : Borrow Book.  Checks are done in this order, and each failure shows a box:
;       1) book exists   2) copies > 0   3) member holds fewer than 3 books
;       4) no unpaid fine   5) member does not already hold this book
;       6) it is his turn: a free copy goes to the reservation queue first (FIFO)
;     Then the book is ISSUED: a new transaction row is added, copies--, the book's
;     borrow count++, the member's total++, and any reservation the member had for
;     this book is removed from the queue.
; ------------------------------------------------------------------------
BorrowBook PROC
    call Clrscr
    mov  edx, OFFSET sTBorrow
    call PrintTitle
    mov  edx, OFFSET sPBookId
    call WriteString
    call ReadInt
    mov  tmpId, eax
    call FindBook
    cmp  eax, -1
    je   bw_nf
    mov  tmpSlot, eax
    mov  ebx, tmpSlot                       ; availability
    cmp  bookCopies[ebx*4], 0
    jle  bw_unavail
    mov  eax, curMemId                      ; eligibility: limit
    call CountCurrent
    cmp  eax, MAX_BORROW   ; limit of 3 books
    jae  bw_limit
    mov  ebx, curMember                     ; eligibility: unpaid fine
    cmp  memFine[ebx*4], 0
    jg   bw_fine
    mov  eax, tmpId                         ; eligibility: already holds it
    call HasBorrowed
    cmp  eax, 1
    je   bw_has
    mov  eax, tmpId                         ; eligibility: is it his turn in the queue?
    call QueueAllows
    cmp  eax, 1
    jne  bw_queue
    cmp  trCount, MAX_TRANS
    jae  bw_tfull
    mov  ecx, trCount                       ; Issue Book
    mov  eax, curMemId
    mov  trMember[ecx*4], eax
    mov  eax, tmpId
    mov  trBook[ecx*4], eax
    mov  trDays[ecx*4], 0
    mov  trReturned[ecx*4], 0
    mov  trFine[ecx*4], 0
    inc  trCount   ; new transaction row added
    mov  ebx, tmpSlot
    dec  bookCopies[ebx*4]                  ; Reduce Available Copies
    inc  bookBorrowCnt[ebx*4]               ; Increase Borrow Count
    mov  ebx, curMember
    inc  memBorrowTotal[ebx*4]              ; Update Member History
    mov  eax, curMemId                      ; drop own reservation (if any)
    mov  edx, tmpId
    call RemoveReservation
    mov  edx, OFFSET msgIssued
    call InfoBox
    ret
bw_nf:
    mov  edx, OFFSET msgNoBook
    call ErrBox
    ret
bw_unavail:
    mov  edx, OFFSET msgUnavail
    call WarnBox
    ret
bw_limit:
    mov  edx, OFFSET msgLimit
    call WarnBox
    ret
bw_fine:
    mov  edx, OFFSET msgFineBlock
    call WarnBox
    ret
bw_has:
    mov  edx, OFFSET msgHasBook
    call WarnBox
    ret
bw_queue:
    mov  edx, OFFSET msgQueueTurn
    call WarnBox
    ret
bw_tfull:
    mov  edx, OFFSET msgTransFull
    call ErrBox
    ret
BorrowBook ENDP

; ------------------------------ 3.4 RETURN --------------------------------
; ------------------------------------------------------------------------
; ReturnBook : Return Book.  Finds the member's unreturned transaction for that book (else
;     "Invalid Return").  Fine = (days kept - 14) * 5 when days kept > 14.  Then:
;     mark returned, store the fine, add it to the member's fine, copies++, PUSH the
;     return on the stack, check the reservation queue (FirstWaiting) and show ONE
;     combined message "Book returned successfully! Late fine: Rs. N".
; ------------------------------------------------------------------------
ReturnBook PROC
    call Clrscr
    mov  edx, OFFSET sTReturn
    call PrintTitle
    mov  edx, OFFSET sPBookId
    call WriteString
    call ReadInt
    mov  tmpId, eax
    mov  ecx, 0                             ; verify member borrowed the book
rt_find:
    cmp  ecx, trCount
    jae  rt_invalid
    mov  eax, trMember[ecx*4]
    cmp  eax, curMemId
    jne  rt_next
    mov  eax, trBook[ecx*4]
    cmp  eax, tmpId
    jne  rt_next
    cmp  trReturned[ecx*4], 0
    je   rt_found
rt_next:
    inc  ecx
    jmp  rt_find
rt_invalid:
    mov  edx, OFFSET msgInvRet
    call ErrBox
    ret
rt_found:
    mov  tmpSlot, ecx                       ; transaction index
    mov  edx, OFFSET sPDays
    call WriteString
    call ReadInt
    cmp  eax, 0
    jge  rt_dayok
    mov  eax, 0
rt_dayok:
    mov  tmpDays, eax
    mov  tmpFine, 0                         ; Calculate Late Fine
    cmp  eax, LOAN_DAYS   ; kept longer than the 14-day loan period?
    jle  rt_nofine
    sub  eax, LOAN_DAYS   ; eax = number of late days
    imul eax, FINE_PER_DAY   ; fine = late days * Rs. 5
    mov  tmpFine, eax
rt_nofine:
    mov  ecx, tmpSlot
    mov  trReturned[ecx*4], 1
    mov  eax, tmpDays
    mov  trDays[ecx*4], eax
    mov  eax, tmpFine
    mov  trFine[ecx*4], eax
    mov  ebx, curMember
    mov  eax, tmpFine
    add  memFine[ebx*4], eax
    mov  eax, tmpId                         ; Increase Available Copies
    call FindBook
    cmp  eax, -1
    je   rt_nocopy
    inc  bookCopies[eax*4]
rt_nocopy:
    mov  eax, tmpId                         ; Add Return to Stack
    mov  edx, curMemId
    call PushReturn   ; add to the recent-returns STACK
    mov  edi, OFFSET msgBuf                 ; ONE combined message
    mov  esi, OFFSET msgRetOk
    call AppendStr
    mov  eax, tmpFine
    call AppendNum
    mov  eax, tmpId                         ; Check Reservation Queue
    call FirstWaiting   ; who is first in the reservation queue for this book?
    cmp  eax, 0
    je   rt_show
    mov  tmpA, eax
    mov  esi, OFFSET msgQNote1
    call AppendStr
    mov  eax, tmpA
    call AppendNum
    mov  esi, OFFSET msgQNote2
    call AppendStr
rt_show:
    mov  edx, OFFSET msgBuf
    call InfoBox
    ret
ReturnBook ENDP

; ------------------------------ 3.5 RESERVE -------------------------------
; ------------------------------------------------------------------------
; ReserveBook : Reserve Book (FIFO queue).  Allowed only when the book has 0 copies, the
;     member does not hold it and is not already queued.  Queue position = number of
;     members already waiting for this book + 1; the member is then ENQUEUED at the
;     tail (index resCount).
; ------------------------------------------------------------------------
ReserveBook PROC
    call Clrscr
    mov  edx, OFFSET sTReserve
    call PrintTitle
    mov  edx, OFFSET sPBookId
    call WriteString
    call ReadInt
    mov  tmpId, eax
    call FindBook
    cmp  eax, -1
    je   rs_nf
    mov  tmpSlot, eax
    mov  ebx, tmpSlot                       ; eligibility checks
    cmp  bookCopies[ebx*4], 0
    jle  rs_check                           ; no copies: normal reservation rules
    mov  eax, tmpId
    call QueueAllows                        ; copies exist - are they free for him?
    cmp  eax, 1
    je   rs_avail                           ; yes: he can simply borrow it
rs_check:
    mov  eax, tmpId
    call HasBorrowed
    cmp  eax, 1
    je   rs_have
    mov  eax, tmpId
    call IsQueued
    cmp  eax, 1
    je   rs_dup
    cmp  resCount, MAX_RES
    jae  rs_full
    mov  eax, tmpId                         ; Calculate Queue Position
    call CountQueue
    inc  eax   ; position = people already waiting + 1
    mov  tmpA, eax
    mov  ecx, resCount                      ; ENQUEUE at the tail (FIFO)
    mov  eax, curMemId
    mov  resMem[ecx*4], eax
    mov  eax, tmpId
    mov  resBook[ecx*4], eax
    inc  resCount   ; ENQUEUE: the new reservation is at the tail
    mov  edi, OFFSET msgBuf
    mov  esi, OFFSET msgResOk
    call AppendStr
    mov  eax, tmpA
    call AppendNum
    mov  edx, OFFSET msgBuf
    call InfoBox
    ret
rs_nf:
    mov  edx, OFFSET msgNoBook
    call ErrBox
    ret
rs_avail:
    mov  edx, OFFSET msgResAvail
    call WarnBox
    ret
rs_have:
    mov  edx, OFFSET msgResHave
    call WarnBox
    ret
rs_dup:
    mov  edx, OFFSET msgResDup
    call WarnBox
    ret
rs_full:
    mov  edx, OFFSET msgResFull
    call ErrBox
    ret
ReserveBook ENDP

; ------------------------------ 3.6 MY HISTORY ----------------------------
; ------------------------------------------------------------------------
; MyHistory : My History: currently borrowed books, previously returned books and the
;     outstanding fine of the logged-in member (ListTrans with fMem = my ID).
; ------------------------------------------------------------------------
MyHistory PROC
    call Clrscr
    mov  edx, OFFSET sTMyHist
    call PrintTitle
    mov  eax, curMemId
    mov  fMem, eax
    mov  edx, OFFSET sCurBorrowed
    call PrintTitle
    mov  fMode, 2
    call ListTrans
    mov  edx, OFFSET sPrevReturned
    call PrintTitle
    mov  fMode, 1
    call ListTrans
    mov  fMem, 0
    mov  edx, OFFSET sOutFine
    call WriteString
    mov  ebx, curMember
    mov  eax, memFine[ebx*4]
    call WriteDec
    call Crlf
    call Crlf
    call WaitMsg
    ret
MyHistory ENDP

; ------------------------------------------------------------------------
; PayFine : Pay Fine: shows the amount paid and clears the member's fine.  Borrowing is
;     blocked while a fine is unpaid, so this lets the member borrow again.
; ------------------------------------------------------------------------
PayFine PROC
    mov  ebx, curMember
    cmp  memFine[ebx*4], 0
    jle  pf_none
    mov  edi, OFFSET msgBuf
    mov  esi, OFFSET msgPaid
    call AppendStr
    mov  eax, memFine[ebx*4]
    call AppendNum
    mov  memFine[ebx*4], 0
    mov  edx, OFFSET msgBuf
    call InfoBox
    ret
pf_none:
    mov  edx, OFFSET msgNoFine
    call InfoBox
    ret
PayFine ENDP

; --------------------------- 3.7 RECOMMENDATIONS --------------------------
; ------------------------------------------------------------------------
; Recommend : Recommendations.  Idea: favourite category = the category that appears most
;     often in the member's history.
;       Step 1: collect the slots of all books the member has borrowed (tmpIdx).
;       Step 2: nested loop - for each of those books count how many have the same
;               category (StrCompareI - ignores capital letters); the biggest count wins.
;       Step 3: list the books of that category the member has NOT read yet.
; ------------------------------------------------------------------------
Recommend PROC
    call Clrscr
    mov  edx, OFFSET sTRecom
    call PrintTitle
    mov  tmpN, 0                            ; collect member's book slots
    mov  ecx, 0
rc_c:
    cmp  ecx, trCount
    jae  rc_cd
    mov  eax, trMember[ecx*4]
    cmp  eax, curMemId
    jne  rc_cn
    mov  eax, trBook[ecx*4]
    call FindBook
    cmp  eax, -1
    je   rc_cn
    mov  ebx, tmpN
    mov  tmpIdx[ebx*4], eax
    inc  tmpN
rc_cn:
    inc  ecx
    jmp  rc_c
rc_cd:
    cmp  tmpN, 0
    jne  rc_have
    mov  edx, OFFSET msgNoHist
    call WriteString
    call Crlf
    call WaitMsg
    ret
rc_have:
    mov  catBestSlot, -1                    ; Identify Favorite Category
    mov  catBestScore, 0
    mov  catI, 0
rc_i:
    mov  eax, catI
    cmp  eax, tmpN
    jae  rc_id
    mov  catSum, 0
    mov  catJ, 0
rc_j:
    mov  eax, catJ
    cmp  eax, tmpN
    jae  rc_jd
    mov  ebx, catI
    mov  eax, tmpIdx[ebx*4]
    mov  edx, OFFSET bookCat
    call StrAt
    mov  ptr1, edx
    mov  ebx, catJ
    mov  eax, tmpIdx[ebx*4]
    mov  edx, OFFSET bookCat
    call StrAt
    mov  ptr2, edx
    mov  esi, ptr1                         ; case-insensitive compare of two categories
    mov  edi, ptr2
    call StrCompareI
    jne  rc_jn
    inc  catSum
rc_jn:
    inc  catJ
    jmp  rc_j
rc_jd:
    mov  eax, catSum
    cmp  eax, catBestScore
    jle  rc_in
    mov  catBestScore, eax
    mov  ebx, catI
    mov  eax, tmpIdx[ebx*4]
    mov  catBestSlot, eax
rc_in:
    inc  catI
    jmp  rc_i
rc_id:
    mov  edx, OFFSET sFavCat
    call WriteString
    mov  edx, OFFSET bookCat
    mov  eax, catBestSlot
    call StrAt
    mov  ptr1, edx                          ; ptr1 = favourite category
    call WriteString
    call Crlf
    mov  edx, OFFSET sRecList
    call PrintTitle
    call PrintBookHeader
    mov  dispCnt, 0
    mov  catI, 0                            ; catI = candidate book slot
rc_b:
    cmp  catI, MAX_BOOKS
    jae  rc_bd
    mov  ebx, catI
    cmp  bookActive[ebx*4], 0
    je   rc_bn
    mov  edx, OFFSET bookCat
    mov  eax, catI
    call StrAt
    mov  ptr2, edx
    mov  esi, ptr1                         ; case-insensitive compare of two categories
    mov  edi, ptr2
    call StrCompareI
    jne  rc_bn
    mov  catJ, 0                            ; skip books already read
rc_k:
    mov  eax, catJ
    cmp  eax, tmpN
    jae  rc_show
    mov  ebx, catJ
    mov  eax, tmpIdx[ebx*4]
    cmp  eax, catI
    je   rc_bn
    inc  catJ
    jmp  rc_k
rc_show:
    inc  dispCnt
    mov  eax, catI
    call PrintBookRow
rc_bn:
    inc  catI
    jmp  rc_b
rc_bd:
    cmp  dispCnt, 0
    jne  rc_end
    mov  edx, OFFSET sRecNone
    call WriteString
rc_end:
    call Crlf
    call WaitMsg
    ret
Recommend ENDP

; ==========================================================================
;                    4.1 FILE STORAGE  (human-readable text)
;   books.txt   : BookID|Name|Author|Category|Copies|BorrowCount
;   members.txt : NextMemberID|n  then  MemberID|Name|PIN|TotalBorrowed|Fine
;   trans.txt   : MemberID|BookID|DaysKept|Returned|Fine  + return stack part
;   reserve.txt : MemberID|BookID   (top line = front of FIFO queue)
; ==========================================================================

; ------------------------------ parsing helpers ---------------------------
; ------------------------------------------------------------------------
; ReadNumField : PARSER: text -> number.  Skips spaces, converts the digits with
;     result = result*10 + digit, then skips spaces and one '|'.
;     Input : esi = cursor (moves forward)      Output: eax = number
; ------------------------------------------------------------------------
; esi = cursor.  Skips spaces, reads digits -> eax, skips spaces and one '|'
ReadNumField PROC uses ebx
    xor  eax, eax
rn_sp1:
    cmp  BYTE PTR [esi], ' '
    jne  rn_loop
    inc  esi
    jmp  rn_sp1
rn_loop:
    movzx ebx, BYTE PTR [esi]
    cmp  bl, '0'
    jb   rn_end
    cmp  bl, '9'
    ja   rn_end
    imul eax, 10   ; result = result * 10 ...
    sub  ebx, '0'   ; ASCII digit -> value 0..9
    add  eax, ebx   ; ... + digit
    inc  esi
    jmp  rn_loop
rn_end:
rn_sp2:
    cmp  BYTE PTR [esi], ' '
    jne  rn_pipe
    inc  esi
    jmp  rn_sp2
rn_pipe:
    cmp  BYTE PTR [esi], '|'
    jne  rn_done
    inc  esi
rn_done:
    ret
ReadNumField ENDP

; ------------------------------------------------------------------------
; ReadStrField : PARSER: copies one text field (up to '|' or end of line) into a name cell,
;     removes leading / trailing spaces (the file is padded for alignment) and null
;     terminates it.   Input: esi = cursor, edi = destination cell
; ------------------------------------------------------------------------
; esi = cursor, edi = destination (NAME_LEN bytes).
; Skips leading spaces, copies text up to '|', removes trailing spaces
ReadStrField PROC uses eax ebx ecx edi
rs_lead:
    cmp  BYTE PTR [esi], ' '
    jne  rs_start
    inc  esi
    jmp  rs_lead
rs_start:
    mov  ebx, edi                  ; start of destination
    mov  ecx, NAME_LEN-1
rs_copy:
    mov  al, [esi]
    cmp  al, '|'
    je   rs_end
    cmp  al, 0Dh
    je   rs_end
    cmp  al, 0Ah
    je   rs_end
    cmp  al, 0
    je   rs_end
    cmp  ecx, 0
    je   rs_skip
    mov  [edi], al
    inc  edi
    dec  ecx
rs_skip:
    inc  esi
    jmp  rs_copy
rs_end:
rs_trim:
    cmp  edi, ebx
    jbe  rs_term
    cmp  BYTE PTR [edi-1], ' '
    jne  rs_term
    dec  edi
    jmp  rs_trim
rs_term:
    mov  BYTE PTR [edi], 0
    cmp  BYTE PTR [esi], '|'
    jne  rs_done
    inc  esi
rs_done:
    ret
ReadStrField ENDP

; ------------------------------------------------------------------------
; NextLine : PARSER: moves the cursor esi to the start of the next line (just after LF).
; ------------------------------------------------------------------------
; esi = cursor : move to the start of the next line
NextLine PROC uses eax
nl_loop:
    mov  al, [esi]
    cmp  al, 0
    je   nl_done
    inc  esi
    cmp  al, 0Ah
    jne  nl_loop
nl_done:
    ret
NextLine ENDP

; ------------------------------------------------------------------------
; SkipEol : PARSER: skips blank lines (CR / LF characters).
; ------------------------------------------------------------------------
; esi = cursor : skip any CR / LF characters (blank lines)
SkipEol PROC uses eax
se_loop:
    mov  al, [esi]
    cmp  al, 0Dh
    je   se_adv
    cmp  al, 0Ah
    je   se_adv
    ret
se_adv:
    inc  esi
    jmp  se_loop
SkipEol ENDP

; ------------------------------------------------------------------------
; SkipToPipe : PARSER: moves the cursor just past the next '|' on the current line.
; ------------------------------------------------------------------------
; esi = cursor : move just past the next '|' on this line
SkipToPipe PROC uses eax
sp_loop:
    mov  al, [esi]
    cmp  al, 0
    je   sp_done
    cmp  al, 0Dh
    je   sp_done
    cmp  al, 0Ah
    je   sp_done
    inc  esi
    cmp  al, '|'
    jne  sp_loop
sp_done:
    ret
SkipToPipe ENDP

; ------------------------------ file helpers ------------------------------
; ------------------------------------------------------------------------
; ReadWholeFile : Reads a complete text file into fileBuf and null-terminates it so the parser
;     knows where the text ends.
;     Input : edx = file name       Output: eax = 1 success, 0 if file missing
;     (a missing file is normal on the first run - the program just starts empty)
; ------------------------------------------------------------------------
; edx = file name -> reads whole file into fileBuf (null terminated)
; returns eax = 1 on success, 0 if the file is missing / unreadable
ReadWholeFile PROC uses ebx ecx edx
    call OpenInputFile
    cmp  eax, -1
    je   rw_fail
    mov  fileHandle, eax
    mov  edx, OFFSET fileBuf
    mov  ecx, FILE_BUF_SIZE-1
    call ReadFromFile   ; Irvine: eax = number of bytes read
    mov  ebx, eax                  ; bytes read
    jc   rw_err
    mov  BYTE PTR fileBuf[ebx], 0   ; null-terminate the text so the parser can detect the end
    mov  eax, fileHandle
    call CloseFile
    mov  eax, 1
    ret
rw_err:
    mov  BYTE PTR fileBuf, 0
    mov  eax, fileHandle
    call CloseFile
rw_fail:
    mov  eax, 0
    ret
ReadWholeFile ENDP

; ------------------------------------------------------------------------
; WriteBuf : Writes the text built in fileBuf to a file (overwrites it).
;     Input : edx = file name, edi = end of the text.  Length = edi - start of buffer.
; ------------------------------------------------------------------------
; edx = file name, edi = end of text in fileBuf -> writes fileBuf to the file
WriteBuf PROC uses eax ebx ecx edx
    mov  ebx, edi
    sub  ebx, OFFSET fileBuf   ; length = end pointer - start of buffer
    mov  blkSize, ebx
    call CreateOutputFile
    cmp  eax, -1
    je   wb_end
    mov  fileHandle, eax
    mov  edx, OFFSET fileBuf
    mov  ecx, blkSize
    call WriteToFile   ; write the whole text in one call
    mov  eax, fileHandle
    call CloseFile
wb_end:
    ret
WriteBuf ENDP

; ------------------------------------------------------------------------
; AppendStrPad : Appends a string and pads it with spaces up to a fixed width.  This produces
;     the aligned columns in the saved text files.   esi = string, ebx = width
; ------------------------------------------------------------------------
; esi = string, ebx = width : append string, then pad with spaces to width
AppendStrPad PROC uses eax ebx ecx edx
    mov  edx, edi
    call AppendStr
    mov  ecx, edi
    sub  ecx, edx
    cmp  ecx, ebx
    jae  asp_done
    sub  ebx, ecx
    mov  ecx, ebx
asp_pad:
    mov  BYTE PTR [edi], ' '
    inc  edi
    loop asp_pad
    mov  BYTE PTR [edi], 0
asp_done:
    ret
AppendStrPad ENDP

; ------------------------------------------------------------------------
; AppendNumPad : Appends a number and pads it with spaces up to a fixed width.
;     eax = number, ebx = width
; ------------------------------------------------------------------------
; eax = number, ebx = width : append number, then pad with spaces to width
AppendNumPad PROC uses eax ebx ecx edx
    mov  edx, edi
    call AppendNum
    mov  ecx, edi
    sub  ecx, edx
    cmp  ecx, ebx
    jae  anp_done
    sub  ebx, ecx
    mov  ecx, ebx
anp_pad:
    mov  BYTE PTR [edi], ' '
    inc  edi
    loop anp_pad
    mov  BYTE PTR [edi], 0
anp_done:
    ret
AppendNumPad ENDP

; ------------------------------- SAVE (aligned columns) -------------
; ------------------------------------------------------------------------
; SaveBooks : Builds books.txt in fileBuf: header + rule line, then one aligned line per
;     ACTIVE book (deleted slots are not saved), and writes it with WriteBuf.
; ------------------------------------------------------------------------
SaveBooks PROC uses eax ebx ecx edx esi edi
    mov  edi, OFFSET fileBuf
    mov  esi, OFFSET hdrBooksFile
    call AppendStr
    mov  ecx, 0
sbk_loop:
    cmp  ecx, MAX_BOOKS
    jae  sbk_done
    cmp  bookActive[ecx*4], 0
    je   sbk_next
    mov  eax, bookId[ecx*4]
    mov  ebx, 6
    call AppendNumPad
    mov  esi, OFFSET sSep
    call AppendStr
    mov  edx, OFFSET bookName
    mov  eax, ecx
    call StrAt
    mov  esi, edx
    mov  ebx, 29
    call AppendStrPad
    mov  esi, OFFSET sSep
    call AppendStr
    mov  edx, OFFSET bookAuthor
    mov  eax, ecx
    call StrAt
    mov  esi, edx
    mov  ebx, 29
    call AppendStrPad
    mov  esi, OFFSET sSep
    call AppendStr
    mov  edx, OFFSET bookCat
    mov  eax, ecx
    call StrAt
    mov  esi, edx
    mov  ebx, 29
    call AppendStrPad
    mov  esi, OFFSET sSep
    call AppendStr
    mov  eax, bookCopies[ecx*4]
    mov  ebx, 6
    call AppendNumPad
    mov  esi, OFFSET sSep
    call AppendStr
    mov  eax, bookBorrowCnt[ecx*4]
    call AppendNum
    mov  esi, OFFSET sCrLf
    call AppendStr
sbk_next:
    inc  ecx
    jmp  sbk_loop
sbk_done:
    mov  edx, OFFSET fBooks
    call WriteBuf
    ret
SaveBooks ENDP

; ------------------------------------------------------------------------
; SaveMembers : Builds members.txt: first line holds NextMemberID (so IDs are never reused),
;     then the header and one line per active member.
; ------------------------------------------------------------------------
SaveMembers PROC uses eax ebx ecx edx esi edi
    mov  edi, OFFSET fileBuf
    mov  esi, OFFSET sNextIdLbl
    call AppendStr
    mov  eax, nextMemberId
    call AppendNum
    mov  esi, OFFSET sCrLf
    call AppendStr
    mov  esi, OFFSET hdrMembersFile
    call AppendStr
    mov  ecx, 0
smb_loop:
    cmp  ecx, MAX_MEMBERS
    jae  smb_done
    cmp  memActive[ecx*4], 0
    je   smb_next
    mov  eax, memId[ecx*4]
    mov  ebx, 8
    call AppendNumPad
    mov  esi, OFFSET sSep
    call AppendStr
    mov  edx, OFFSET memName
    mov  eax, ecx
    call StrAt
    mov  esi, edx
    mov  ebx, 29
    call AppendStrPad
    mov  esi, OFFSET sSep
    call AppendStr
    mov  eax, memPin[ecx*4]
    mov  ebx, 6
    call AppendNumPad
    mov  esi, OFFSET sSep
    call AppendStr
    mov  eax, memBorrowTotal[ecx*4]
    mov  ebx, 13
    call AppendNumPad
    mov  esi, OFFSET sSep
    call AppendStr
    mov  eax, memFine[ecx*4]
    call AppendNum
    mov  esi, OFFSET sCrLf
    call AppendStr
smb_next:
    inc  ecx
    jmp  smb_loop
smb_done:
    mov  edx, OFFSET fMembers
    call WriteBuf
    ret
SaveMembers ENDP

; ------------------------------------------------------------------------
; SaveTrans : Builds trans.txt: all transaction rows, then a second section [RETURN STACK]
;     holding the stack from bottom to top.
; ------------------------------------------------------------------------
SaveTrans PROC uses eax ebx ecx edx esi edi
    mov  edi, OFFSET fileBuf
    mov  esi, OFFSET hdrTransFile
    call AppendStr
    mov  ecx, 0
str_loop:
    cmp  ecx, trCount
    jae  str_done
    mov  eax, trMember[ecx*4]
    mov  ebx, 8
    call AppendNumPad
    mov  esi, OFFSET sSep
    call AppendStr
    mov  eax, trBook[ecx*4]
    mov  ebx, 6
    call AppendNumPad
    mov  esi, OFFSET sSep
    call AppendStr
    mov  eax, trDays[ecx*4]
    mov  ebx, 8
    call AppendNumPad
    mov  esi, OFFSET sSep
    call AppendStr
    mov  eax, trReturned[ecx*4]
    mov  ebx, 15
    call AppendNumPad
    mov  esi, OFFSET sSep
    call AppendStr
    mov  eax, trFine[ecx*4]
    call AppendNum
    mov  esi, OFFSET sCrLf
    call AppendStr
str_next:
    inc  ecx
    jmp  str_loop
str_done:
    mov  esi, OFFSET hdrStackFile
    call AppendStr
    mov  ecx, 0
sts_loop:
    cmp  ecx, retTop
    jae  sts_done
    mov  eax, retStackMem[ecx*4]
    mov  ebx, 8
    call AppendNumPad
    mov  esi, OFFSET sSep
    call AppendStr
    mov  eax, retStackBook[ecx*4]
    call AppendNum
    mov  esi, OFFSET sCrLf
    call AppendStr
sts_next:
    inc  ecx
    jmp  sts_loop
sts_done:
    mov  edx, OFFSET fTrans
    call WriteBuf
    ret
SaveTrans ENDP

; ------------------------------------------------------------------------
; SaveReserve : Builds reserve.txt: the reservation queue, first line = front of the queue.
; ------------------------------------------------------------------------
SaveReserve PROC uses eax ebx ecx edx esi edi
    mov  edi, OFFSET fileBuf
    mov  esi, OFFSET hdrResFile
    call AppendStr
    mov  ecx, 0
srv_loop:
    cmp  ecx, resCount
    jae  srv_done
    mov  eax, resMem[ecx*4]
    mov  ebx, 8
    call AppendNumPad
    mov  esi, OFFSET sSep
    call AppendStr
    mov  eax, resBook[ecx*4]
    call AppendNum
    mov  esi, OFFSET sCrLf
    call AppendStr
srv_next:
    inc  ecx
    jmp  srv_loop
srv_done:
    mov  edx, OFFSET fReserve
    call WriteBuf
    ret
SaveReserve ENDP

; ------------------------------------------------------------------------
; SaveAll : Saves all four files.  Called after every logout and before the program exits.
; ------------------------------------------------------------------------
SaveAll PROC
    call SaveBooks
    call SaveMembers
    call SaveTrans
    call SaveReserve
    ret
SaveAll ENDP

; ------------------------------- LOAD -------------------------------------
; ------------------------------------------------------------------------
; LoadBooks : Reads books.txt back: skips the two header lines, then for each line parses
;     ID, name, author, category, copies and borrow count into the next free slot and
;     marks it active.  (Slots are filled from 0, so deleted records disappear.)
; ------------------------------------------------------------------------
LoadBooks PROC uses eax ebx ecx edx esi edi
    mov  edx, OFFSET fBooks
    call ReadWholeFile
    cmp  eax, 0
    je   lbk_end
    mov  esi, OFFSET fileBuf
    call NextLine                          ; skip header line
    call NextLine                          ; skip rule line
    mov  ecx, 0
lbk_loop:
    call SkipEol
    cmp  BYTE PTR [esi], 0
    je   lbk_end
    cmp  ecx, MAX_BOOKS
    jae  lbk_end
    call ReadNumField
    mov  bookId[ecx*4], eax
    mov  eax, ecx
    imul eax, NAME_LEN
    mov  edi, OFFSET bookName
    add  edi, eax
    call ReadStrField
    mov  eax, ecx
    imul eax, NAME_LEN
    mov  edi, OFFSET bookAuthor
    add  edi, eax
    call ReadStrField
    mov  eax, ecx
    imul eax, NAME_LEN
    mov  edi, OFFSET bookCat
    add  edi, eax
    call ReadStrField
    call ReadNumField
    mov  bookCopies[ecx*4], eax
    call ReadNumField
    mov  bookBorrowCnt[ecx*4], eax
    mov  bookActive[ecx*4], 1
    call NextLine
    inc  ecx
    jmp  lbk_loop
lbk_end:
    ret
LoadBooks ENDP

; ------------------------------------------------------------------------
; LoadMembers : Reads members.txt: first the NextMemberID line, then one member per line.
; ------------------------------------------------------------------------
LoadMembers PROC uses eax ebx ecx edx esi edi
    mov  edx, OFFSET fMembers
    call ReadWholeFile
    cmp  eax, 0
    je   lmb_end
    mov  esi, OFFSET fileBuf
    call SkipToPipe                        ; "NextMemberID|"
    call ReadNumField
    cmp  eax, 0
    je   lmb_nonext
    mov  nextMemberId, eax
lmb_nonext:
    call NextLine                          ; finish line 1
    call NextLine                          ; skip column header
    call NextLine                          ; skip rule line
    mov  ecx, 0
lmb_loop:
    call SkipEol
    cmp  BYTE PTR [esi], 0
    je   lmb_end
    cmp  ecx, MAX_MEMBERS
    jae  lmb_end
    call ReadNumField
    mov  memId[ecx*4], eax
    mov  eax, ecx
    imul eax, NAME_LEN
    mov  edi, OFFSET memName
    add  edi, eax
    call ReadStrField
    call ReadNumField
    mov  memPin[ecx*4], eax
    call ReadNumField
    mov  memBorrowTotal[ecx*4], eax
    call ReadNumField
    mov  memFine[ecx*4], eax
    mov  memActive[ecx*4], 1
    call NextLine
    inc  ecx
    jmp  lmb_loop
lmb_end:
    ret
LoadMembers ENDP

; ------------------------------------------------------------------------
; LoadTrans : Reads trans.txt: transaction rows until the line starting with '[' (a digit
;     check), then the return-stack section.  Sets trCount and retTop.
; ------------------------------------------------------------------------
LoadTrans PROC uses eax ebx ecx edx esi edi
    mov  edx, OFFSET fTrans
    call ReadWholeFile
    cmp  eax, 0
    je   ltr_end
    mov  esi, OFFSET fileBuf
    call NextLine                          ; skip header line
    call NextLine                          ; skip rule line
    mov  ecx, 0
ltr_loop:
    call SkipEol
    mov  al, [esi]
    cmp  al, '0'
    jb   ltr_stack                         ; not a digit: end of records
    cmp  al, '9'
    ja   ltr_stack
    cmp  ecx, MAX_TRANS
    jae  ltr_stack
    call ReadNumField
    mov  trMember[ecx*4], eax
    call ReadNumField
    mov  trBook[ecx*4], eax
    call ReadNumField
    mov  trDays[ecx*4], eax
    call ReadNumField
    mov  trReturned[ecx*4], eax
    call ReadNumField
    mov  trFine[ecx*4], eax
    call NextLine
    inc  ecx
    jmp  ltr_loop
ltr_stack:
    mov  trCount, ecx
    cmp  BYTE PTR [esi], 0
    je   ltr_end
    call NextLine                          ; "[RETURN STACK ...]" line
    call NextLine                          ; column header
    call NextLine                          ; rule line
    mov  ecx, 0
ltr_sl:
    call SkipEol
    cmp  BYTE PTR [esi], 0
    je   ltr_sd
    cmp  ecx, MAX_STACK
    jae  ltr_sd
    call ReadNumField
    mov  retStackMem[ecx*4], eax
    call ReadNumField
    mov  retStackBook[ecx*4], eax
    call NextLine
    inc  ecx
    jmp  ltr_sl
ltr_sd:
    mov  retTop, ecx
ltr_end:
    ret
LoadTrans ENDP

; ------------------------------------------------------------------------
; LoadReserve : Reads reserve.txt into the queue arrays and sets resCount.
; ------------------------------------------------------------------------
LoadReserve PROC uses eax ebx ecx edx esi edi
    mov  edx, OFFSET fReserve
    call ReadWholeFile
    cmp  eax, 0
    je   lrv_end
    mov  esi, OFFSET fileBuf
    call NextLine                          ; skip header line
    call NextLine                          ; skip rule line
    mov  ecx, 0
lrv_loop:
    call SkipEol
    cmp  BYTE PTR [esi], 0
    je   lrv_done
    cmp  ecx, MAX_RES
    jae  lrv_done
    call ReadNumField
    mov  resMem[ecx*4], eax
    call ReadNumField
    mov  resBook[ecx*4], eax
    call NextLine
    inc  ecx
    jmp  lrv_loop
lrv_done:
    mov  resCount, ecx
lrv_end:
    ret
LoadReserve ENDP

; ------------------------------------------------------------------------
; LoadAll : Loads all four files once, at program start-up.
; ------------------------------------------------------------------------
LoadAll PROC
    call LoadBooks
    call LoadMembers
    call LoadTrans
    call LoadReserve
    ret
LoadAll ENDP

END main