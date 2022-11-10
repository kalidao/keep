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
    MINT, // mint an asset
    BURN, // burn an asset
    CLAIM, // set asset up for claim
    SALE, // set asset up for sale
    LICENSE, // set asset up for license 
    DERIVATIVE, // set asset up for derivative work
    DISPUTE // set asset up for ADR
}

enum TokenType {
    FUNGIBLE,
    NONFUNGIBLE,
    ERC20,
    ERC721,
    ERC1155
}

/// @author audsssy.eth
contract TradingPost is ERC1155, ERC1155TokenReceiver, ReentrancyGuard {
    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------

    event AdminSet(address indexed caller, address indexed to);

    event ManagerSet(address indexed caller, address indexed to);

    event TokenPauseSet(address indexed caller, uint256[] ids, bool[] pauses);

    event BaseURIset(address indexed caller, string baseURI);

    event InsuranceRateSet(address indexed caller, uint256 insuranceRate);

    /// -----------------------------------------------------------------------
    /// Custom Errors
    /// -----------------------------------------------------------------------

    error InvalidDeadline();

    error TradeExpired();

    error InvalidLicense();

    error InvalidDerivative();

    error NotAuthorized(); // could refactor to use Unauthorized() in ERC1155

    /// -----------------------------------------------------------------------
    /// TradingPost Storage
    /// -----------------------------------------------------------------------

    string public name;

    string private baseURI;

    // uint8 public insuranceRate;

    // uint256 public insurance;

    address public admin;
    
    address public manager;

    IKaliAccessManager private immutable accessManager;

    // address private immutable wETH;

    uint256 public tradeCount;

    mapping(uint256 => Trade) public trades;

    mapping(uint256 => string) private tokenURIs;

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
        // uint8 _insuranceRate,
        IKaliAccessManager _accessManager
    ) payable {
        name = _name;

        baseURI = _baseURI;

        // insuranceRate = _insuranceRate;

        admin = msg.sender;

        accessManager = _accessManager;

        emit BaseURIset(address(0), _baseURI);

        // emit InsuranceRateSet(address(0), insuranceRate);

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

    /// @notice Set parameter for a trade
    /// @param tradeType Type of trade.
    /// @param list The allow list for trade.
    /// @param ids The IDs of assets for trade.
    /// @param amounts The amounts of assets for trade.
    /// @param _tokenURIs The metadata of assets for trade.
    /// @param currency The token address required to complete a trade.
    /// @param payment The amount required to complete a trade.
    /// @param expiry The deadline to complete a trade.
    /// @param docs The document associated with a trade.
    /// @param data Data for compliant ERC1155 transfer.
    /// @dev 
    function setTrade(
        TradeType tradeType,
        uint256 list,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        string[] calldata _tokenURIs,
        address currency,
        uint256 payment, // SALE / LICENSE - payment, CLAIM - list id
        uint96 expiry,
        string calldata docs,
        bytes calldata data
    ) external payable onlyAuthorized {
        if (ids.length != amounts.length) revert LengthMismatch();
        if (ids.length != _tokenURIs.length) revert LengthMismatch();
        if (expiry > block.timestamp) revert InvalidDeadline();
        
        unchecked {
            tradeCount++;
        }
        // Retain insurance for LICENSE trades
        // if (tradeType == TradeType.LICENSE) {
        //     unchecked {
        //         require(
        //             msg.value == (1 ether * insuranceRate) / 1000,
        //             "NOT_FEE"
        //         );
        //         insurance = msg.value + insurance;
        //     }
        // }

        if (tradeType == TradeType.MINT) {
            mint(ids, amounts, data, _tokenURIs);

            // Update Trade only if payment is defined
            if (payment != 0) {
                trades[tradeCount] = Trade({
                    tradeType: TradeType.SALE,
                    list: list,
                    ids: ids,
                    amounts: amounts,
                    currency: currency,
                    payment: payment,
                    expiry: expiry,
                    docs: docs
                });
            }
        } else if (tradeType == TradeType.BURN) {
            burn(ids, amounts);
        } else {
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
            // transferAssets(tradeCount, admin, address(this), false, data);
        }
    }

    function completeTrade(
        uint256 trade,
        string calldata tokenUri,
        bytes calldata data
    ) external payable {
        if (trades[trade].expiry > block.timestamp) revert TradeExpired();

        // Check if access list enforced
        if (trades[trade].list != 0) {
            if (accessManager.balanceOf(msg.sender, trades[trade].list) != 0) 
                revert NotAuthorized() ;
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
        // Mint agreement NFT per asset(s)
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

    function setBaseURI(string calldata _baseURI) external payable onlyAuthorized {
        baseURI = _baseURI;

        emit BaseURIset(msg.sender, _baseURI);
    }

    // function setInsuranceRate(uint8 _insuranceRate) external payable onlyAuthorized {
    //     insuranceRate = _insuranceRate;

    //     emit InsuranceRateSet(msg.sender, _insuranceRate);
    // }

    function claimFee(address to, uint256 amount) external payable onlyAuthorized {
        // Admin cannot claim insurance
        // require(address(this).balance - amount >= insurance, "OVERDRAFT");

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
            licenseId = type(uint256).max / 3;
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
            derivativeId = type(uint256).max / 3 * 2;
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