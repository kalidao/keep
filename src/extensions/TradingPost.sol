// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import { ERC1155, ERC1155TokenReceiver } from "@solbase/src/tokens/ERC1155/ERC1155.sol";
import { SafeMulticallable } from "@solbase/src/utils/SafeMulticallable.sol";
import { ReentrancyGuard } from "@solbase/src/utils/ReentrancyGuard.sol";
import { safeTransferETH, safeTransfer, safeTransferFrom } from "@solbase/src/utils/SafeTransfer.sol";

/// @notice Kali access manager interface
interface IKaliAccessManager {
    function balanceOf(address account, uint256 id) external returns (uint256);
}

/// @title TradingPost
/// @notice A marketplace for on-chain orgs.
/// @author audsssy.eth | KaliCo LLC

struct Trade {
    TradeType tradeType;
    uint256 list;
    uint256[] ids;
    uint256[] amounts;
    address currency;
    uint256 payment;
    uint96 expiry;
    string docs;
}

struct Trial {
    uint256 trade;
    address currency;
    uint256 amount;
}

enum TradeType {
    MINT, // mint an asset
    BURN, // burn an asset
    CLAIM, // set asset up for claim
    SALE, // set asset up for sale
    LICENSE, // set asset up for license (lump-sum only)
    DERIVATIVE, // set asset up for derivative work 
    REFUND // refund an asset
}

contract TradingPost is ERC1155, ERC1155TokenReceiver, ReentrancyGuard, SafeMulticallable {
    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------

    event AdminSet(address indexed caller, address indexed to);

    event ManagerSet(address indexed caller, address indexed to);

    event TokenPauseSet(address indexed caller, uint256[] ids, bool[] pauses);

    event BaseURIset(address indexed caller, string baseURI);

    /// -----------------------------------------------------------------------
    /// Custom Errors
    /// -----------------------------------------------------------------------

    error InvalidAction();
    
    error InvalidDeadline();

    error InvalidTrial();

    error TrialExpired();

    error TradeExpired();

    error InvalidLicense();

    error InvalidDerivative();

    error NotAuthorized(); // could refactor to use Unauthorized() in ERC1155

    /// -----------------------------------------------------------------------
    /// TradingPost Storage
    /// -----------------------------------------------------------------------

    string public name;

    string private baseURI;

    address public admin;
    
    address public manager;

    IKaliAccessManager private immutable accessManager;

    uint256 public tradeCount;

    uint40 public trialLength;

    mapping(uint256 => Trade) public trades;

    mapping(uint256 => string) private tokenURIs;

    // mapping(address => uint256) private trial;

    mapping(address => Trade[]) private trials;

    modifier onlyAuthorized() {
        if (msg.sender != admin || msg.sender != manager) revert NotAuthorized();

        _;
    }

    function uri(uint256 id) public view override returns (string memory) {
        if (bytes(tokenURIs[id]).length == 0) return baseURI;
        else return tokenURIs[id];
    }

    /// -----------------------------------------------------------------------
    /// Constructor
    /// -----------------------------------------------------------------------

    constructor(
        string memory _name,
        string memory _baseURI,
        IKaliAccessManager _accessManager,
        uint40 _trialLength
    ) payable {
        name = _name;

        baseURI = _baseURI;

        admin = msg.sender;

        accessManager = _accessManager;

        trialLength = _trialLength;

        emit BaseURIset(address(0), _baseURI);

        emit AdminSet(address(0), admin);
    }

    /// -----------------------------------------------------------------------
    /// Internal Functions
    /// -----------------------------------------------------------------------

    function mint(
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data,
        string[] calldata _tokenURIs
    ) internal onlyAuthorized {
        __batchMint(address(this), ids, amounts, data, _tokenURIs);
    }

    function burn(
        uint256[] calldata ids,
        uint256[] calldata amounts
    ) internal onlyAuthorized {
        _batchBurn(address(this), ids, amounts);
    }

    /// -----------------------------------------------------------------------
    /// TradingPost Logic
    /// -----------------------------------------------------------------------

    /// @notice Manage assets by minting or burning them.
    /// @param tradeType Type of Trade.
    /// @param ids The IDs of assets for Trade.
    /// @param amounts The amounts of assets for Trade.
    /// @param _tokenURIs The metadata of assets for Trade.
    /// @param data Data for compliant ERC1155 transfer.
    /// @dev 
    function manageAsset(
        TradeType tradeType,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        string[] calldata _tokenURIs,
        bytes calldata data
    ) external payable {
        if (tradeType != TradeType.MINT || tradeType != TradeType.BURN) revert InvalidAction();

        if (tradeType == TradeType.MINT) {
            mint(ids, amounts, data, _tokenURIs);
        } else if (tradeType == TradeType.BURN) {
            burn(ids, amounts);
        } else {
        }
    }

    /// @notice Set parameter for a Trade
    /// @param tradeType Type of Trade.
    /// @param list The allow list for Trade.
    /// @param ids The IDs of assets for Trade.
    /// @param amounts The amounts of assets for Trade.
    /// @param currency The token address required to complete Trade.
    /// @param payment The amount required to complete Trade.
    /// @param expiry The deadline to complete Trade.
    /// @param docs The document associated with a trade.
    /// @dev 
    function setTrade(
        TradeType tradeType,
        uint256 list,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        address currency,
        uint256 payment,
        uint96 expiry,
        string calldata docs
    ) external payable onlyAuthorized {
        if (ids.length != amounts.length) revert LengthMismatch();
        if (expiry > block.timestamp) revert InvalidDeadline();
        
        unchecked {            
            tradeCount++;
        }

        trades[tradeCount] = Trade({
            tradeType: tradeType,
            list: list,
            ids: ids,
            amounts: amounts,
            currency: currency,
            payment: payment,
            expiry: expiry,
            docs: docs
        });
    }

    function completeTrade(
        bool trial,
        uint256 trialId,
        uint256 trade,
        string calldata tokenUri,
        bytes calldata data
    ) external payable {
        if (trial) {
            // REFUND
            // Refund Trade for refund
            Trade memory _trial = trials[msg.sender][trialId];
            if (_trial.tradeType != TradeType.REFUND) revert InvalidTrial();
            if (_trial.expiry < block.timestamp) revert TrialExpired();

            this.safeBatchTransferFrom(msg.sender, address(this), _trial.ids, _trial.amounts, data);
            processPayment(_trial.currency, _trial.payment, msg.sender);
        } else {
            if (trades[trade].expiry > block.timestamp) revert TradeExpired();

            // Check if access list enforced
            if (trades[trade].list != 0) {
                if (accessManager.balanceOf(msg.sender, trades[trade].list) != 0) 
                    revert NotAuthorized() ;
            }

            // CLAIM
            // Transfer asset(s) for free
            if (trades[trade].tradeType == TradeType.CLAIM) {
                this.safeBatchTransferFrom(address(this), msg.sender, trades[trade].ids, trades[trade].amounts, data);
            }

            // SALE
            // Pay for asset(s)
            if (trades[trade].tradeType == TradeType.SALE) {
                processPayment(trades[trade].currency, trades[trade].payment, address(this));
                startTrial(trade);
                this.safeBatchTransferFrom(address(this), msg.sender, trades[trade].ids, trades[trade].amounts, data);
            }

            // LICENSE
            // Mint agreement NFT per asset(s)
            if (trades[trade].tradeType == TradeType.LICENSE) {
                processPayment(trades[trade].currency, trades[trade].payment, address(this));
                __mint(trade, tokenUri, data);
            }

            // DERIVATIVE
            // Mint new asset based on existing asset(s)
            if (trades[trade].tradeType == TradeType.DERIVATIVE) {
                processPayment(trades[trade].currency, trades[trade].payment, address(this));
                ___mint(trade, tokenUri, data);
            }
        }
    }

    function getTradeArrays(uint256 trade)
        public
        view
        virtual
        returns (uint256[] memory ids, uint256[] memory amounts)
    {
        Trade storage t = trades[trade];

        (ids, amounts) = (t.ids, t.amounts);
    }

    /// -----------------------------------------------------------------------
    /// Admin Functions
    /// -----------------------------------------------------------------------

    function setBaseURI(string calldata _baseURI) external payable onlyAuthorized {
        baseURI = _baseURI;

        emit BaseURIset(msg.sender, _baseURI);
    }

    function setAdmin(address to) external payable onlyAuthorized {
        admin = to;

        emit AdminSet(msg.sender, to);
    }

    function setManager(address to) external payable onlyAuthorized {
        manager = to;

        emit ManagerSet(msg.sender, to);
    }

    /// -----------------------------------------------------------------------
    /// Internal Functions
    /// -----------------------------------------------------------------------

    function __batchMint(
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data,
        string[] calldata _tokenURIs
    ) internal {
        _batchMint(to, ids, amounts, data);

        uint256 idsLength = ids.length;

        for (uint256 i = 0; i < idsLength; ) {
            if (bytes(tokenURIs[i]).length != 0) {
                tokenURIs[ids[i]] = _tokenURIs[i];

                emit URI(_tokenURIs[i], ids[i]);
            }

            // An array can't have a total length
            // larger than the max uint256 value.
            unchecked {
                ++i;
            }
        }
    }

    // Mint license token
    function __mint(
        uint256 trade,
        string memory docs,
        bytes calldata data
    ) internal {
        if (bytes(docs).length == 0) revert InvalidLicense();

        uint256 licenseId;

        unchecked {
            licenseId = type(uint256).max / 3 + trade;
        }

        tokenURIs[licenseId] = docs;
        _mint(msg.sender, licenseId, 1, data);

        emit URI(docs, licenseId);
    }

    // Mint derivative token
    function ___mint(
        uint256 trade,
        string memory docs,
        bytes calldata data
    ) internal {
        if (bytes(docs).length == 0) revert InvalidDerivative();

        uint256 derivativeId;

        unchecked {
            derivativeId = type(uint256).max / 3 * 2 + trade;
        }

        tokenURIs[derivativeId] = docs;
        _mint(msg.sender, derivativeId, 1, data);

        emit URI(docs, derivativeId);
    }

    function processPayment(address currency, uint256 amount, address to) internal {
        if (currency == address(0)) {
            safeTransferETH(to, amount);
        } else {
            safeTransfer(currency, to, amount);
        }
    }

    function startTrial(uint256 trade) internal {
        uint40 trialDeadline;

        unchecked{ 
            trialDeadline = uint40(block.timestamp) + trialLength;
        }

        if (trialDeadline > 0 && trialDeadline > block.timestamp) {
            trials[msg.sender].push(Trade({
                tradeType: TradeType.REFUND,
                list: 0,
                ids: trades[trade].ids,
                amounts: trades[trade].amounts,
                currency: trades[trade].currency,
                payment: trades[trade].payment,
                expiry: trialDeadline,
                docs: ""
            }));
        }
    }
}