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
