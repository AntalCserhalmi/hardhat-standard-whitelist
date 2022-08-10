//Contract based on [https://docs.openzeppelin.com/contracts/3.x/erc721](https://docs.openzeppelin.com/contracts/3.x/erc721)
// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract StandardERC721Whitelist is ERC721URIStorage, Ownable {
    using Strings for uint256;
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    bytes32 public merkleRoot;
    uint256 public totalSupply;
    uint256 public collectionSize;
    uint256 public maxPerWallet;
    uint256 public costPublic;
    uint256 public cost;
    uint256 public devMints;

    string public baseURI;
    string public notRevealedURI;

    bool public mintEnabled = false;
    bool public publicMintEnabled = false;
    bool public revealed = false;
    bool public paused = false;

    mapping(address => uint256) public walletMints;

    constructor(
        uint256 totalSupply_,
        uint256 collectionSize_,
        uint256 maxPerWallet_,
        uint256 cost_,
        uint256 devMints_,
        string memory baseURI_,
        string memory notRevealedURI_
    ) ERC721("StandardERC721", "STANDARD") {
        totalSupply = totalSupply_;
        collectionSize = collectionSize_;
        maxPerWallet = maxPerWallet_;
        cost = cost_;
        devMints = devMints_;
        baseURI = baseURI_;
        notRevealedURI = notRevealedURI_;
    }

    //OnlyOwner - Setters
    function setMerkleRoot(bytes32 merkleRoot_) external onlyOwner{
        merkleRoot = merkleRoot_;
    }

    function setCollectionSize(uint256 collectionSize_) external onlyOwner {
        collectionSize = collectionSize_;
    }

    function setTotalSupply(uint256 totalSupply_) external onlyOwner {
        totalSupply = totalSupply_;
    }

    function setMaxPerWallet(uint256 maxPerWallet_) external onlyOwner {
        maxPerWallet = maxPerWallet_;
    }

    function pauseMinting(bool paused_) external onlyOwner {
        paused = paused_;
    }

    function setBaseURI(string calldata baseURI_) external onlyOwner {
        baseURI = baseURI_;
    }

    function setNotRevealedURI(string calldata notRevealedURI_)
        external
        onlyOwner
    {
        notRevealedURI = notRevealedURI_;
    }

    function setDevMints(uint256 devMints_) external onlyOwner {
        devMints = devMints_;
    }

    function setCost(uint256 cost_) external onlyOwner {
        cost = cost_;
    }

    function setMintStatus(bool status_) external onlyOwner {
        mintEnabled = status_;
    }

    //Override
    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );

        if (revealed == false) {
            return notRevealedURI;
        }

        string memory currentBaseURI = baseURI;
        return
            bytes(currentBaseURI).length > 0
                ? string(
                    abi.encodePacked(
                        currentBaseURI,
                        tokenId.toString(),
                        ".json"
                    )
                )
                : "";
    }

    function getWalletMints(address wallet_) external view returns (uint256) {
        return walletMints[wallet_];
    }

    //Modifiers

    modifier MintEnabled() {
        require(mintEnabled, "Minting is not started yet");
        _;
    }

    modifier Paused() {
        require(!paused, "Mint is paused at this moment");
        _;
    }

    modifier MaxLimit(uint256 quantity_) {
        require(
            totalSupply + quantity_ <= collectionSize,
            "All NFT have been minted out"
        );
        _;
    }

    modifier MaxPerWallet(uint256 quantity_) {
        require(
            walletMints[msg.sender] + quantity_ <= maxPerWallet,
            "Exceed max mint per wallet"
        );
        _;
    }

    modifier MinimalValue(uint quantity_) {
        require(
            msg.value * quantity_ >= cost * quantity_,
            "Not enough Ether for mint"
        );
        _;
    }

    function mint(uint256 quantity_, address to_) internal {
        for (uint256 i = 0; i < quantity_; i++) {
            _tokenIds.increment();
            uint256 newItemId = _tokenIds.current();
            _safeMint(to_, newItemId);
            totalSupply++;
        }

        walletMints[to_] += quantity_;
    }

    function mintPublic(uint256 quantity_)
        external
        payable
        MintEnabled
        Paused
        MaxLimit(quantity_)
        MaxPerWallet(quantity_)
    {
        require(msg.value * quantity_ >= costPublic * quantity_, "Not enough Ether for public mint");
        require(publicMintEnabled, "Public mint is not started");
        mint(quantity_, msg.sender);
    }

    //Only for WL
    function mintWhitelist(uint256 quantity_, bytes32[] calldata merkleProof_)
        external
        payable
        MintEnabled
        Paused
        MaxLimit(quantity_)
        MaxPerWallet(quantity_)
        MinimalValue(quantity_)
    {
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
        require(
            MerkleProof.verify(merkleProof_, merkleRoot, leaf), "Invalid Proof"
        );

        mint(quantity_, msg.sender);
    }

    //Owner Only
    function reveal(bool revealed_) external onlyOwner {
        revealed = revealed_;
    }

    function withdraw(address to_, uint256 amount) external onlyOwner {
        if (amount > address(this).balance || amount == 0) {
            amount = address(this).balance;
        }
        payable(to_).transfer(amount);
    }

    function mintForAddress(uint256 quantity_, address to_) 
        external 
        onlyOwner 
        MaxLimit(quantity_)
    {
        mint(quantity_, to_);
    }

    function devMint(uint256 amount_) external onlyOwner {
        require(walletMints[msg.sender] + amount_ < devMints, "Exceed devmint");

        mint(amount_, msg.sender);
    }
}
