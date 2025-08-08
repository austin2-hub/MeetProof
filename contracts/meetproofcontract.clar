;; title: meetproofcontract
;; version: 1.0.0
;; summary: Decentralized proof-of-meeting protocol with NFT minting
;; description: A smart contract that enables trustless verification of real-world interactions
;;              between multiple parties using location proofs and cryptographic secrets.
;;              Participants who successfully verify their presence at a meeting location
;;              receive NFTs as permanent proof of attendance.

;; traits
(impl-trait 'SP2PABAF9FTAJYNFZH93XENAJ8FVY99RRM50D2JG9.nft-trait.nft-trait)
(use-trait nft-trait 'SP2PABAF9FTAJYNFZH93XENAJ8FVY99RRM50D2JG9.nft-trait.nft-trait)

;; token definitions
(define-non-fungible-token meetproof-nft uint)

;; constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u401))
(define-constant ERR-INVALID-LOCATION (err u100))
(define-constant ERR-INVALID-SECRET (err u101))
(define-constant ERR-SESSION-NOT-STARTED (err u102))
(define-constant ERR-SESSION-EXPIRED (err u103))
(define-constant ERR-MIN-PARTICIPANTS-NOT-MET (err u104))
(define-constant ERR-ALREADY-PARTICIPATED (err u105))
(define-constant ERR-SESSION-NOT-FOUND (err u106))
(define-constant ERR-NFT-NOT-FOUND (err u107))
(define-constant ERR-INVALID-RADIUS (err u108))
(define-constant ERR-INVALID-DURATION (err u109))
(define-constant ERR-NFT-ALREADY-MINTED (err u110))
(define-constant ERR-TRANSFER-FAILED (err u111))

(define-constant MAX-PARTICIPANTS u50)
(define-constant MAX-RADIUS u10000) ;; 10km in meters
(define-constant MIN-RADIUS u10)    ;; 10m minimum
(define-constant MAX-DURATION u1000) ;; max blocks for session
(define-constant MIN-DURATION u5)   ;; min blocks for session
(define-constant EARTH-RADIUS u6371000) ;; Earth radius in meters
(define-constant SCALE-FACTOR u1000000) ;; for lat/lon precision

;; data vars
(define-data-var session-counter uint u0)
(define-data-var nft-counter uint u0)
(define-data-var contract-paused bool false)

;; data maps
(define-map sessions uint {
    initiator: principal,
    secret-hash: (buff 32),
    location: { lat: int, lon: int },
    radius: uint,
    start-block: uint,
    end-block: uint,
    min-participants: uint,
    max-participants: uint,
    participants: (list 50 principal),
    nft-minted: bool,
    metadata-uri: (optional (string-utf8 200))
})

(define-map nft-metadata uint {
    timestamp: uint,
    block-height: uint,
    location: { lat: int, lon: int },
    participants: (list 50 principal),
    session-id: uint,
    metadata-uri: (optional (string-utf8 200))
})

(define-map participant-sessions principal (list 100 uint))
(define-map session-participants uint (list 50 principal))



;; public functions

;; Create a new meeting session
(define-public (create-session 
                (secret (buff 6)) 
                (location {lat: int, lon: int}) 
                (radius uint) 
                (duration uint)
                (min-participants uint)
                (max-participants uint))
    (let ((session-id (+ (var-get session-counter) u1)))
        ;; Validate inputs
        (asserts! (not (var-get contract-paused)) ERR-NOT-AUTHORIZED)
        (asserts! (and (>= radius MIN-RADIUS) (<= radius MAX-RADIUS)) ERR-INVALID-RADIUS)
        (asserts! (and (>= duration MIN-DURATION) (<= duration MAX-DURATION)) ERR-INVALID-DURATION)
        (asserts! (and (>= min-participants u2) (<= min-participants max-participants)) ERR-MIN-PARTICIPANTS-NOT-MET)
        (asserts! (<= max-participants MAX-PARTICIPANTS) ERR-MIN-PARTICIPANTS-NOT-MET)
        (asserts! (and (>= (get lat location) -90000000) (<= (get lat location) 90000000)) ERR-INVALID-LOCATION)
        (asserts! (and (>= (get lon location) -180000000) (<= (get lon location) 180000000)) ERR-INVALID-LOCATION)
        
        ;; Create session
        (map-set sessions session-id {
            initiator: tx-sender,
            secret-hash: (sha256 secret),
            location: location,
            radius: radius,
            start-block: block-height,
            end-block: (+ block-height duration),
            min-participants: min-participants,
            max-participants: max-participants,
            participants: (list),
            nft-minted: false,
            metadata-uri: none
        })
        
        ;; Update counter
        (var-set session-counter session-id)
        
        ;; Add to initiator's sessions
        (update-participant-sessions tx-sender session-id)
        
        (ok session-id)))

;; Verify participation in a meeting session
(define-public (verify-participation 
               (session-id uint) 
               (secret (buff 6)) 
               (location {lat: int, lon: int}))
    (let ((session (unwrap! (map-get? sessions session-id) ERR-SESSION-NOT-FOUND))
          (current-participants (get participants session)))
        
        ;; Validate session and participation
        (asserts! (not (var-get contract-paused)) ERR-NOT-AUTHORIZED)
        (asserts! (>= block-height (get start-block session)) ERR-SESSION-NOT-STARTED)
        (asserts! (<= block-height (get end-block session)) ERR-SESSION-EXPIRED)
        (asserts! (is-eq (sha256 secret) (get secret-hash session)) ERR-INVALID-SECRET)
        (asserts! (is-valid-location? (get location session) location (get radius session)) ERR-INVALID-LOCATION)
        (asserts! (is-none (index-of current-participants tx-sender)) ERR-ALREADY-PARTICIPATED)
        (asserts! (< (len current-participants) (get max-participants session)) ERR-MIN-PARTICIPANTS-NOT-MET)
        
        ;; Add participant to session
        (let ((new-participants (unwrap! (as-max-len? (append current-participants tx-sender) u50) ERR-MIN-PARTICIPANTS-NOT-MET)))
            (map-set sessions session-id 
                (merge session { participants: new-participants }))
            
            ;; Update participant's session list
            (update-participant-sessions tx-sender session-id)
            
            ;; Try to mint NFT if conditions are met
            (try! (maybe-mint-nft session-id))
            
            (ok true))))

;; Mint NFT when minimum participants reached
(define-public (mint-meeting-nft (session-id uint))
    (let ((session (unwrap! (map-get? sessions session-id) ERR-SESSION-NOT-FOUND))
          (participants (get participants session)))
        
        ;; Validate minting conditions
        (asserts! (not (get nft-minted session)) ERR-NFT-ALREADY-MINTED)
        (asserts! (>= (len participants) (get min-participants session)) ERR-MIN-PARTICIPANTS-NOT-MET)
        (asserts! (> block-height (get end-block session)) ERR-SESSION-NOT-STARTED) ;; Session must be ended
        
        ;; Mint NFT
        (let ((nft-id (+ (var-get nft-counter) u1)))
            (var-set nft-counter nft-id)
            
            ;; Store NFT metadata
            (map-set nft-metadata nft-id {
                timestamp: (unwrap! (get-block-info? time (get end-block session)) ERR-SESSION-NOT-FOUND),
                block-height: (get end-block session),
                location: (get location session),
                participants: participants,
                session-id: session-id,
                metadata-uri: (get metadata-uri session)
            })
            
            ;; Mark session as minted
            (map-set sessions session-id (merge session { nft-minted: true }))
            
            ;; Mint NFTs to all participants
            (fold mint-to-participant participants (ok nft-id)))))

;; Set metadata URI for a session (only initiator)
(define-public (set-session-metadata-uri (session-id uint) (metadata-uri (string-utf8 200)))
    (let ((session (unwrap! (map-get? sessions session-id) ERR-SESSION-NOT-FOUND)))
        (asserts! (is-eq tx-sender (get initiator session)) ERR-NOT-AUTHORIZED)
        (map-set sessions session-id (merge session { metadata-uri: (some metadata-uri) }))
        (ok true)))

;; Emergency pause/unpause (contract owner only)
(define-public (set-contract-paused (paused bool))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (var-set contract-paused paused)
        (ok true)))

;; NFT transfer function
(define-public (transfer (token-id uint) (sender principal) (recipient principal))
    (begin
        (asserts! (is-eq tx-sender sender) ERR-NOT-AUTHORIZED)
        (asserts! (is-some (nft-get-owner? meetproof-nft token-id)) ERR-NFT-NOT-FOUND)
        (nft-transfer? meetproof-nft token-id sender recipient)))


;; read only functions

;; Get session details
(define-read-only (get-session (session-id uint))
    (map-get? sessions session-id))

;; Get NFT metadata
(define-read-only (get-nft-metadata (nft-id uint))
    (map-get? nft-metadata nft-id))

;; Verify meeting authenticity
(define-read-only (verify-meeting (nft-id uint))
    (let ((metadata (unwrap! (map-get? nft-metadata nft-id) ERR-NFT-NOT-FOUND))
          (session (unwrap! (map-get? sessions (get session-id metadata)) ERR-SESSION-NOT-FOUND)))
        (ok {
            valid: true,
            session-id: (get session-id metadata),
            timestamp: (get timestamp metadata),
            location: (get location metadata),
            participants: (get participants metadata),
            verified-at-block: (get block-height metadata)
        })))

;; Get participant's sessions
(define-read-only (get-participant-sessions (participant principal))
    (default-to (list) (map-get? participant-sessions participant)))

;; Get current session counter
(define-read-only (get-session-counter)
    (var-get session-counter))

;; Get current NFT counter
(define-read-only (get-nft-counter)
    (var-get nft-counter))

;; Check if contract is paused
(define-read-only (is-contract-paused)
    (var-get contract-paused))

;; NFT trait functions
(define-read-only (get-last-token-id)
    (ok (var-get nft-counter)))

(define-read-only (get-token-uri (token-id uint))
    (let ((metadata (map-get? nft-metadata token-id)))
        (match metadata
            meta (ok (get metadata-uri meta))
            (ok none))))

(define-read-only (get-owner (token-id uint))
    (ok (nft-get-owner? meetproof-nft token-id)))