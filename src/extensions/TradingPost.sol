// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import { ERC1155 } from "@solbase/src/tokens/ERC1155/ERC1155.sol";
import { ERC1155TokenReceiver } from "../KeepToken.sol";
import { SafeMulticallable } from "@solbase/src/utils/SafeMulticallable.sol";
import { ReentrancyGuard } from "@solbase/src/utils/ReentrancyGuard.sol";
import { safeTransferETH, safeTransfer, safeTransferFrom } from "@solbase/src/utils/SafeTransfer.sol";

/// @notice Kali DAO access manager interface
interface IKaliAccessManager {
    function balanceOf(address account, uint256 id) external returns (uint256);
}

/// @title TradingPost
/// @author KaliCo LLC
/// @notice TradingPost for on-chain entities.

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

enum TradeType {
    UNAVAILABLE,
    CLAIM,
    SALE,
    LICENSE,
    DERIVATIVE
}

/// @author audsssy.eth
contract TradingPost is ERC1155, ERC1155TokenReceiver, ReentrancyGuard {
    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------

    event AdminSet(address indexed caller, address indexed to);

    event TokenPauseSet(address indexed caller, uint256[] ids, bool[] pauses);

    event BaseURIset(address indexed caller, string baseURI);

    event InsuranceRateSet(address indexed caller, uint256 insuranceRate);

    /// -----------------------------------------------------------------------
    /// TradingPost Storage
    /// -----------------------------------------------------------------------

    string public name;

    string private baseURI;

    uint8 public insuranceRate;

    uint256 public insurance;

    address public admin;

    IKaliAccessManager private immutable accessManager;

    // address private immutable wETH;

    uint256 public tradeCount;

    mapping(uint256 => Trade) public trades;

    mapping(uint256 => string) private tokenURIs;

    modifier onlyAdmin() {
        require(msg.sender == admin, "NOT_ADMIN");

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
        uint8 _insuranceRate,
        IKaliAccessManager _accessManager
    ) payable {
        name = _name;

        baseURI = _baseURI;

        insuranceRate = _insuranceRate;

        admin = msg.sender;

        accessManager = _accessManager;

        emit BaseURIset(address(0), _baseURI);

        emit InsuranceRateSet(address(0), insuranceRate);

        emit AdminSet(address(0), admin);
    }

    /// -----------------------------------------------------------------------
    /// Internal Functions
    /// -----------------------------------------------------------------------

    function manageMint(
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data,
        string[] calldata _tokenURIs
    ) internal {
        require(msg.sender == admin, "NOT_AUTHORIZED");

        __batchMint(admin, ids, amounts, data, _tokenURIs);
    }

    function manageBurn(
        address from,
        uint256[] calldata ids,
        uint256[] calldata amounts
    ) internal {
        require(msg.sender == admin, "NOT_AUTHORIZED");

        _batchBurn(from, ids, amounts);
    }

    /// -----------------------------------------------------------------------
    /// TradingPost Logic
    /// -----------------------------------------------------------------------

    /// @notice Set trading post task
    /// @param to The Keep to make tribute to.
    /// @param asset The token address for tribute.
    /// @param std The EIP interface for tribute `asset`.
    /// @param tokenId The ID of `asset` to make tribute in.
    /// @param amount The amount of `asset` to make tribute in.
    /// @param forId The ERC1155 Keep token ID to make tribute for.
    /// @param forAmount The ERC1155 Keep token ID amount to make tribute for.
    /// @return id The Keep escrow ID assigned incrementally for each tribute.
    /// @dev The `tokenId` will be used where tribute `asset` is ERC721 or ERC1155.
    function setTrade(
        TradeType tradeType,
        uint256 list,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        address currency,
        uint256 payment, // SALE / LICENSE - payment, CLAIM - list id
        uint96 expiry,
        string calldata docs,
        bytes calldata data
    ) external payable {
        require(msg.sender == admin, "NOT_AUTHORIZED");
        require(expiry > block.timestamp, "INVALID_EXPIRY");

        // Retain insurance for LICENSE trades
        if (tradeType == TradeType.LICENSE) {
            // cannot possibly overflow on human timescale
            unchecked {
                require(
                    msg.value == (1 ether * insuranceRate) / 1000,
                    "NOT_FEE"
                );
                insurance = msg.value + insurance;
            }
        }

        unchecked {
            tradeCount++;
        }

        trades[tradeCount].tradeType = tradeType;
        trades[tradeCount].list = list;
        trades[tradeCount].ids = ids;
        trades[tradeCount].amounts = amounts;
        trades[tradeCount].currency = currency;
        trades[tradeCount].payment = payment;
        trades[tradeCount].expiry = expiry;
        trades[tradeCount].docs = docs;

        // Transfer Trade subject matter to TradingPost indicating intention to trade
        transferAssets(tradeCount, admin, address(this), false, data);
    }

    function completeTrade(
        uint256 trade,
        string calldata tokenUri,
        bytes calldata data
    ) external payable {
        require(
            trades[trade].tradeType != TradeType.UNAVAILABLE,
            "TRADE_UNAVAILABLE"
        );
        require(trades[trade].expiry > block.timestamp, "TRADE_EXPIRED");

        // Check if access list enforced
        if (trades[trade].list != 0) {
            require(
                accessManager.balanceOf(msg.sender, trades[trade].list) != 0,
                "NOT_LISTED"
            );
        }

        // CLAIM
        // Transfer asset(s) for free
        if (trades[trade].tradeType == TradeType.CLAIM) {
            transferAssets(trade, address(this), msg.sender, true, data);
        }

        // SALE
        // Transfer asset(s) with a fee
        if (trades[trade].tradeType == TradeType.SALE) {
            processTradingFee(trades[trade].currency, trades[trade].payment);
            transferAssets(trade, address(this), msg.sender, true, data);
        }

        // LICENSE
        // Mint usage agreement per asset(s)
        if (trades[trade].tradeType == TradeType.LICENSE) {
            processTradingFee(trades[trade].currency, trades[trade].payment);
            __mint(trade, trades[trade].docs, data);
        }

        // DERIVATIVE
        // Mint new asset based on existing asset(s)
        if (trades[trade].tradeType == TradeType.DERIVATIVE) {
            processTradingFee(trades[trade].currency, trades[trade].payment);
            ___mint(trade, tokenUri, data);
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

    function setBaseURI(string calldata _baseURI) external payable onlyAdmin {
        baseURI = _baseURI;

        emit BaseURIset(msg.sender, _baseURI);
    }

    function setInsuranceRate(uint8 _insuranceRate) external payable onlyAdmin {
        insuranceRate = _insuranceRate;

        emit InsuranceRateSet(msg.sender, _insuranceRate);
    }

    function claimFee(address to, uint256 amount) external payable onlyAdmin {
        // Admin cannot claim insurance
        require(address(this).balance - amount >= insurance, "OVERDRAFT");

        assembly {
            // Transfer the ETH and check if it succeeded or not.
            if iszero(call(gas(), to, amount, 0, 0, 0, 0)) {
                mstore(0x00, hex"08c379a0") // Function selector of the error method.
                mstore(0x04, 0x20) // Offset of the error string.
                mstore(0x24, 19) // Length of the error string.
                mstore(0x44, "ETH_TRANSFER_FAILED") // The error string.
                revert(0x00, 0x64) // Revert with (offset, size).
            }
        }
    }

    function setAdmin(address to) external payable onlyAdmin {
        admin = to;

        emit AdminSet(msg.sender, to);
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

        require(idsLength == _tokenURIs.length, "LENGTH_MISMATCH");

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
        require(bytes(docs).length == 0, "LICENSE_UNDEFINED");

        uint256 licenseId;

        unchecked {
            licenseId = 10**20 + trade;
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
        require(bytes(docs).length == 0, "DERIVATIVE_NOT_FOUND");

        uint256 derivativeId;

        unchecked {
            derivativeId = 2 * 10**20 + trade;
        }

        tokenURIs[derivativeId] = docs;
        _mint(msg.sender, derivativeId, 1, data);

        emit URI(docs, derivativeId);
    }

    function processTradingFee(address currency, uint256 amount) internal {
        if (currency == address(0)) {
            // send ETH to DAO
            admin._safeTransferETH(amount);
        } else if (currency == address(0xDead)) {
            // send ETH to wETH
            wETH._safeTransferETH(amount);
            // send wETH to DAO
            wETH._safeTransfer(admin, amount);
        } else {
            // send tokens to DAO
            currency._safeTransferFrom(msg.sender, admin, amount);
        }
    }

    function transferAssets(
        uint256 trade,
        address from,
        address to,
        bool outbound,
        bytes calldata data
    ) internal {
        //  uint256 idLength = trades[trade].ids.length;

        if (outbound) {
            // initialize an array of 1s with idLength length to restrict outbound transfers to 1 per tx
            uint256[] memory arrayOfOnes;
            safeBatchTransferFrom(
                from,
                to,
                trades[trade].ids,
                arrayOfOnes,
                data
            );
        } else {
            safeBatchTransferFrom(
                from,
                to,
                trades[trade].ids,
                trades[trade].amounts,
                data
            );
        }
    }
}