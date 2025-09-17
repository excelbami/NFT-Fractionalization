(impl-trait .sip-010-trait.sip-010-trait)

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_OWNER_ONLY (err u100))
(define-constant ERR_NOT_TOKEN_OWNER (err u101))
(define-constant ERR_INSUFFICIENT_BALANCE (err u102))
(define-constant ERR_INVALID_AMOUNT (err u103))
(define-constant ERR_NFT_NOT_FOUND (err u104))
(define-constant ERR_ALREADY_FRACTIONALIZED (err u105))
(define-constant ERR_NOT_ALL_FRACTIONS_OWNED (err u106))
(define-constant ERR_TRANSFER_FAILED (err u107))
(define-constant ERR_MINT_FAILED (err u108))
(define-constant ERR_BURN_FAILED (err u109))

(define-fungible-token fraction-token)

(define-data-var token-name (string-ascii 32) "FracNFT")
(define-data-var token-symbol (string-ascii 10) "FNFT")
(define-data-var token-decimals uint u6)
(define-data-var token-uri (optional (string-utf8 256)) none)

(define-map fractionalized-nfts
  { nft-contract: principal, nft-id: uint }
  { 
    original-owner: principal,
    total-fractions: uint,
    fractions-outstanding: uint,
    fraction-price: uint,
    is-active: bool
  }
)

(define-map user-balances principal uint)
(define-map user-nft-fractions { user: principal, nft-contract: principal, nft-id: uint } uint)

(define-read-only (get-name)
  (ok (var-get token-name))
)

(define-read-only (get-symbol)
  (ok (var-get token-symbol))
)

(define-read-only (get-decimals)
  (ok (var-get token-decimals))
)

(define-read-only (get-balance (who principal))
  (ok (default-to u0 (map-get? user-balances who)))
)

(define-read-only (get-total-supply)
  (ok (ft-get-supply fraction-token))
)

(define-read-only (get-token-uri)
  (ok (var-get token-uri))
)

(define-read-only (get-fractionalized-nft (nft-contract principal) (nft-id uint))
  (map-get? fractionalized-nfts { nft-contract: nft-contract, nft-id: nft-id })
)

(define-read-only (get-user-fraction-balance (user principal) (nft-contract principal) (nft-id uint))
  (default-to u0 (map-get? user-nft-fractions { user: user, nft-contract: nft-contract, nft-id: nft-id }))
)

(define-public (transfer (amount uint) (from principal) (to principal) (memo (optional (buff 34))))
  (begin
    (asserts! (or (is-eq from tx-sender) (is-eq from CONTRACT_OWNER)) ERR_NOT_TOKEN_OWNER)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (>= (get-balance-uint from) amount) ERR_INSUFFICIENT_BALANCE)
    
    (try! (ft-transfer? fraction-token amount from to))
    (map-set user-balances from (- (get-balance-uint from) amount))
    (map-set user-balances to (+ (get-balance-uint to) amount))
    
    (print { 
      action: "transfer", 
      from: from, 
      to: to, 
      amount: amount,
      memo: memo
    })
    (ok true)
  )
)

(define-public (fractionalize-nft 
  (nft-contract <nft-trait>) 
  (nft-id uint) 
  (total-fractions uint) 
  (fraction-price uint))
  (let (
    (nft-principal (contract-of nft-contract))
    (nft-key { nft-contract: nft-principal, nft-id: nft-id })
  )
    (asserts! (> total-fractions u0) ERR_INVALID_AMOUNT)
    (asserts! (> fraction-price u0) ERR_INVALID_AMOUNT)
    (asserts! (is-none (map-get? fractionalized-nfts nft-key)) ERR_ALREADY_FRACTIONALIZED)
    
    (try! (contract-call? nft-contract transfer nft-id tx-sender (as-contract tx-sender)))
    
    (map-set fractionalized-nfts nft-key {
      original-owner: tx-sender,
      total-fractions: total-fractions,
      fractions-outstanding: total-fractions,
      fraction-price: fraction-price,
      is-active: true
    })
    
    (try! (ft-mint? fraction-token total-fractions tx-sender))
    (map-set user-balances tx-sender (+ (get-balance-uint tx-sender) total-fractions))
    (map-set user-nft-fractions 
      { user: tx-sender, nft-contract: nft-principal, nft-id: nft-id } 
      total-fractions)
    
    (print { 
      action: "fractionalize", 
      nft-contract: nft-principal, 
      nft-id: nft-id, 
      total-fractions: total-fractions,
      owner: tx-sender
    })
    (ok true)
  )
)

(define-public (buy-fractions 
  (nft-contract principal) 
  (nft-id uint) 
  (fraction-amount uint))
  (let (
    (nft-key { nft-contract: nft-contract, nft-id: nft-id })
    (nft-data (unwrap! (map-get? fractionalized-nfts nft-key) ERR_NFT_NOT_FOUND))
    (total-cost (* fraction-amount (get fraction-price nft-data)))
    (current-owner (get original-owner nft-data))
  )
    (asserts! (> fraction-amount u0) ERR_INVALID_AMOUNT)
    (asserts! (get is-active nft-data) ERR_NFT_NOT_FOUND)
    (asserts! (>= (get-balance-uint current-owner) fraction-amount) ERR_INSUFFICIENT_BALANCE)
    
    (try! (stx-transfer? total-cost tx-sender current-owner))
    (try! (ft-transfer? fraction-token fraction-amount current-owner tx-sender))
    
    (map-set user-balances current-owner (- (get-balance-uint current-owner) fraction-amount))
    (map-set user-balances tx-sender (+ (get-balance-uint tx-sender) fraction-amount))
    
    (map-set user-nft-fractions 
      { user: current-owner, nft-contract: nft-contract, nft-id: nft-id }
      (- (get-user-fraction-balance current-owner nft-contract nft-id) fraction-amount))
    
    (map-set user-nft-fractions 
      { user: tx-sender, nft-contract: nft-contract, nft-id: nft-id }
      (+ (get-user-fraction-balance tx-sender nft-contract nft-id) fraction-amount))
    
    (print { 
      action: "buy-fractions", 
      buyer: tx-sender, 
      nft-contract: nft-contract, 
      nft-id: nft-id, 
      amount: fraction-amount,
      cost: total-cost
    })
    (ok true)
  )
)

(define-public (reconstruct-nft (nft-contract <nft-trait>) (nft-id uint))
  (let (
    (nft-principal (contract-of nft-contract))
    (nft-key { nft-contract: nft-principal, nft-id: nft-id })
    (nft-data (unwrap! (map-get? fractionalized-nfts nft-key) ERR_NFT_NOT_FOUND))
    (total-fractions (get total-fractions nft-data))
    (user-fractions (get-user-fraction-balance tx-sender nft-principal nft-id))
  )
    (asserts! (get is-active nft-data) ERR_NFT_NOT_FOUND)
    (asserts! (is-eq user-fractions total-fractions) ERR_NOT_ALL_FRACTIONS_OWNED)
    
    (try! (as-contract (contract-call? nft-contract transfer nft-id tx-sender tx-sender)))
    (try! (ft-burn? fraction-token total-fractions tx-sender))
    
    (map-set user-balances tx-sender (- (get-balance-uint tx-sender) total-fractions))
    (map-delete user-nft-fractions { user: tx-sender, nft-contract: nft-principal, nft-id: nft-id })
    
    (map-set fractionalized-nfts nft-key (merge nft-data { is-active: false }))
    
    (print { 
      action: "reconstruct", 
      owner: tx-sender, 
      nft-contract: nft-principal, 
      nft-id: nft-id 
    })
    (ok true)
  )
)

(define-public (sell-fractions 
  (nft-contract principal) 
  (nft-id uint) 
  (fraction-amount uint) 
  (price-per-fraction uint))
  (let (
    (user-fractions (get-user-fraction-balance tx-sender nft-contract nft-id))
  )
    (asserts! (> fraction-amount u0) ERR_INVALID_AMOUNT)
    (asserts! (> price-per-fraction u0) ERR_INVALID_AMOUNT)
    (asserts! (>= user-fractions fraction-amount) ERR_INSUFFICIENT_BALANCE)
    
    (print { 
      action: "list-fractions", 
      seller: tx-sender, 
      nft-contract: nft-contract, 
      nft-id: nft-id,
      amount: fraction-amount,
      price: price-per-fraction
    })
    (ok true)
  )
)

(define-private (get-balance-uint (who principal))
  (default-to u0 (map-get? user-balances who))
)

(define-read-only (is-dao-or-extension)
  (ok true)
)

(define-trait nft-trait
  (
    (transfer (uint principal principal) (response bool uint))
    (get-owner (uint) (response (optional principal) uint))
  )
)
