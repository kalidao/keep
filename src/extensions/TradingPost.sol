// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

/// @notice Minimalist and gas efficient standard ERC1155 implementation.
/// @author Solmate (https://github.com/Rari-Capital/solmate/blob/main/src/tokens/ERC1155.sol)
abstract contract ERC1155 {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event TransferSingle(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256 id,
        uint256 amount
    );

    event TransferBatch(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256[] ids,
        uint256[] amounts
    );

    event ApprovalForAll(
        address indexed owner,
        address indexed operator,
        bool approved
    );

    event URI(string value, uint256 indexed id);

    /*//////////////////////////////////////////////////////////////
                             ERC1155 STORAGE
    //////////////////////////////////////////////////////////////*/

    mapping(address => mapping(uint256 => uint256)) public balanceOf;

    mapping(address => mapping(address => bool)) public isApprovedForAll;

    /*//////////////////////////////////////////////////////////////
                             METADATA LOGIC
    //////////////////////////////////////////////////////////////*/

    function uri(uint256 id) public view virtual returns (string memory);

    /*//////////////////////////////////////////////////////////////
                              ERC1155 LOGIC
    //////////////////////////////////////////////////////////////*/

    function setApprovalForAll(address operator, bool approved) public virtual {
        isApprovedForAll[msg.sender][operator] = approved;

        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) public virtual {
        require(
            msg.sender == from || isApprovedForAll[from][msg.sender],
            "NOT_AUTHORIZED"
        );

        balanceOf[from][id] -= amount;
        balanceOf[to][id] += amount;

        emit TransferSingle(msg.sender, from, to, id, amount);

        if (to.code.length != 0) {
            require(
                ERC1155TokenReceiver(to).onERC1155Received(
                    msg.sender,
                    from,
                    id,
                    amount,
                    data
                ) == ERC1155TokenReceiver.onERC1155Received.selector,
                "UNSAFE_RECIPIENT"
            );
        } else require(to != address(0), "INVALID_RECIPIENT");
    }

    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes calldata data
    ) public virtual {
        require(ids.length == amounts.length, "LENGTH_MISMATCH");

        require(
            msg.sender == from || isApprovedForAll[from][msg.sender],
            "NOT_AUTHORIZED"
        );

        // Storing these outside the loop saves ~15 gas per iteration.
        uint256 id;
        uint256 amount;

        for (uint256 i = 0; i < ids.length; ) {
            id = ids[i];
            amount = amounts[i];

            balanceOf[from][id] -= amount;
            balanceOf[to][id] += amount;

            // An array can't have a total length
            // larger than the max uint256 value.
            unchecked {
                ++i;
            }
        }

        emit TransferBatch(msg.sender, from, to, ids, amounts);

        if (to.code.length != 0) {
            require(
                ERC1155TokenReceiver(to).onERC1155BatchReceived(
                    msg.sender,
                    from,
                    ids,
                    amounts,
                    data
                ) == ERC1155TokenReceiver.onERC1155BatchReceived.selector,
                "UNSAFE_RECIPIENT"
            );
        } else require(to != address(0), "INVALID_RECIPIENT");
    }

    function balanceOfBatch(address[] calldata owners, uint256[] calldata ids)
        public
        view
        virtual
        returns (uint256[] memory balances)
    {
        require(owners.length == ids.length, "LENGTH_MISMATCH");

        balances = new uint256[](owners.length);

        // Unchecked because the only math done is incrementing
        // the array index counter which cannot possibly overflow.
        unchecked {
            for (uint256 i = 0; i < owners.length; ++i) {
                balances[i] = balanceOf[owners[i]][ids[i]];
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                              ERC165 LOGIC
    //////////////////////////////////////////////////////////////*/

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        returns (bool)
    {
        return
            interfaceId == 0x01ffc9a7 || // ERC165 Interface ID for ERC165
            interfaceId == 0xd9b67a26 || // ERC165 Interface ID for ERC1155
            interfaceId == 0x0e89341c; // ERC165 Interface ID for ERC1155MetadataURI
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL MINT/BURN LOGIC
    //////////////////////////////////////////////////////////////*/

    function _mint(
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) internal virtual {
        balanceOf[to][id] += amount;

        emit TransferSingle(msg.sender, address(0), to, id, amount);

        if (to.code.length != 0) {
            require(
                ERC1155TokenReceiver(to).onERC1155Received(
                    msg.sender,
                    address(0),
                    id,
                    amount,
                    data
                ) == ERC1155TokenReceiver.onERC1155Received.selector,
                "UNSAFE_RECIPIENT"
            );
        } else require(to != address(0), "INVALID_RECIPIENT");
    }

    function _batchMint(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual {
        uint256 idsLength = ids.length; // Saves MLOADs.

        require(idsLength == amounts.length, "LENGTH_MISMATCH");

        for (uint256 i = 0; i < idsLength; ) {
            balanceOf[to][ids[i]] += amounts[i];

            // An array can't have a total length
            // larger than the max uint256 value.
            unchecked {
                ++i;
            }
        }

        emit TransferBatch(msg.sender, address(0), to, ids, amounts);

        if (to.code.length != 0) {
            require(
                ERC1155TokenReceiver(to).onERC1155BatchReceived(
                    msg.sender,
                    address(0),
                    ids,
                    amounts,
                    data
                ) == ERC1155TokenReceiver.onERC1155BatchReceived.selector,
                "UNSAFE_RECIPIENT"
            );
        } else require(to != address(0), "INVALID_RECIPIENT");
    }

    function _batchBurn(
        address from,
        uint256[] memory ids,
        uint256[] memory amounts
    ) internal virtual {
        uint256 idsLength = ids.length; // Saves MLOADs.

        require(idsLength == amounts.length, "LENGTH_MISMATCH");

        for (uint256 i = 0; i < idsLength; ) {
            balanceOf[from][ids[i]] -= amounts[i];

            // An array can't have a total length
            // larger than the max uint256 value.
            unchecked {
                ++i;
            }
        }

        emit TransferBatch(msg.sender, from, address(0), ids, amounts);
    }

    function _burn(
        address from,
        uint256 id,
        uint256 amount
    ) internal virtual {
        balanceOf[from][id] -= amount;

        emit TransferSingle(msg.sender, from, address(0), id, amount);
    }
}

/// @notice A generic interface for a contract which properly accepts ERC1155 tokens.
/// @author Solmate (https://github.com/Rari-Capital/solmate/blob/main/src/tokens/ERC1155.sol)
abstract contract ERC1155TokenReceiver {
    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) external virtual returns (bytes4) {
        return ERC1155TokenReceiver.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    ) external virtual returns (bytes4) {
        return ERC1155TokenReceiver.onERC1155BatchReceived.selector;
    }
}

/// @notice Safe ETH and ERC-20 transfer library that gracefully handles missing return values
/// @author Modified from Solmate (https://github.com/Rari-Capital/solmate/blob/main/src/utils/SafeTransferLib.sol)
/// License-Identifier: AGPL-3.0-only
library SafeTransferLib {
    /// -----------------------------------------------------------------------
    /// Errors
    /// -----------------------------------------------------------------------

    error ETHtransferFailed();
    error TransferFailed();
    error TransferFromFailed();

    /// -----------------------------------------------------------------------
    /// ETH Logic
    /// -----------------------------------------------------------------------

    function _safeTransferETH(address to, uint256 amount) internal {
        bool success;

        assembly {
            // transfer the ETH and store if it succeeded or not
            success := call(gas(), to, amount, 0, 0, 0, 0)
        }
        if (!success) revert ETHtransferFailed();
    }

    /// -----------------------------------------------------------------------
    /// ERC-20 Logic
    /// -----------------------------------------------------------------------

    function _safeTransfer(
        address token,
        address to,
        uint256 amount
    ) internal {
        bool success;

        assembly {
            // we'll write our calldata to this slot below, but restore it later
            let memPointer := mload(0x40)
            // write the abi-encoded calldata into memory, beginning with the function selector
            mstore(
                0,
                0xa9059cbb00000000000000000000000000000000000000000000000000000000
            )
            mstore(4, to) // append the 'to' argument
            mstore(36, amount) // append the 'amount' argument

            success := and(
                // set success to whether the call reverted, if not we check it either
                // returned exactly 1 (can't just be non-zero data), or had no return data
                or(
                    and(eq(mload(0), 1), gt(returndatasize(), 31)),
                    iszero(returndatasize())
                ),
                // we use 68 because that's the total length of our calldata (4 + 32 * 2)
                // - counterintuitively, this call() must be positioned after the or() in the
                // surrounding and() because and() evaluates its arguments from right to left
                call(gas(), token, 0, 0, 68, 0, 32)
            )

            mstore(0x60, 0) // restore the zero slot to zero
            mstore(0x40, memPointer) // restore the memPointer
        }
        if (!success) revert TransferFailed();
    }

    function _safeTransferFrom(
        address token,
        address from,
        address to,
        uint256 amount
    ) internal {
        bool success;

        assembly {
            // we'll write our calldata to this slot below, but restore it later
            let memPointer := mload(0x40)
            // write the abi-encoded calldata into memory, beginning with the function selector
            mstore(
                0,
                0x23b872dd00000000000000000000000000000000000000000000000000000000
            )
            mstore(4, from) // append the 'from' argument
            mstore(36, to) // append the 'to' argument
            mstore(68, amount) // append the 'amount' argument

            success := and(
                // set success to whether the call reverted, if not we check it either
                // returned exactly 1 (can't just be non-zero data), or had no return data
                or(
                    and(eq(mload(0), 1), gt(returndatasize(), 31)),
                    iszero(returndatasize())
                ),
                // we use 100 because that's the total length of our calldata (4 + 32 * 3)
                // - counterintuitively, this call() must be positioned after the or() in the
                // surrounding and() because and() evaluates its arguments from right to left
                call(gas(), token, 0, 0, 100, 0, 32)
            )

            mstore(0x60, 0) // restore the zero slot to zero
            mstore(0x40, memPointer) // restore the memPointer
        }
        if (!success) revert TransferFromFailed();
    }
}

/// @notice Helper utility that enables calling multiple local methods in a single call.
/// @author Modified from Uniswap (https://github.com/Uniswap/v3-periphery/blob/main/contracts/base/Multicall.sol)
abstract contract Multicall {
    function multicall(bytes[] calldata data)
        external
        returns (bytes[] memory results)
    {
        results = new bytes[](data.length);

        for (uint256 i; i < data.length; ) {
            (bool success, bytes memory result) = address(this).delegatecall(
                data[i]
            );

            if (!success) {
                if (result.length < 68) revert();

                assembly {
                    result := add(result, 0x04)
                }

                revert(abi.decode(result, (string)));
            }

            results[i] = result;

            // An array can't have a total length
            // larger than the max uint256 value.
            unchecked {
                ++i;
            }
        }
    }
}

/// @notice Kali DAO access manager interface
interface IKaliAccessManager {
    function balanceOf(address account, uint256 id) external returns (uint256);
}

/// @title TradingPost
/// @author KaliCo LLC
/// @notice TradingPost for on-chain entities.
contract TradingPost is ERC1155, Multicall {
    using SafeTransferLib for address;

    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------

    event ManagerSet(address indexed caller, address indexed to, bool approval);

    event AdminSet(address indexed caller, address indexed to);

    event AdrSet(address indexed caller, address indexed to);

    event TokenPauseSet(address indexed caller, uint256[] ids, bool[] pauses);

    event BaseURIset(address indexed caller, string baseURI);

    event InsuranceRateSet(address indexed caller, uint256 insuranceRate);

    /// -----------------------------------------------------------------------
    /// TradingPost Storage/Logic
    /// -----------------------------------------------------------------------

    string public name;

    string public symbol;

    string private baseURI;

    uint8 public insuranceRate;

    uint256 public insurance;

    address public admin;

    address public adr;

    IKaliAccessManager private immutable accessManager;

    address private immutable wETH;

    uint256 public tradeCount;

    uint256 private MAX_UINT = type(uint256).max;

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

    mapping(uint256 => Trade) public trades;

    mapping(address => bool) public manager;

    mapping(uint256 => bool) public paused;

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
        string memory _symbol,
        string memory _baseURI,
        uint8 _insuranceRate,
        address _admin,
        address _adr,
        address _wETH,
        IKaliAccessManager _accessManager
    ) payable {
        name = _name;

        symbol = _symbol;

        baseURI = _baseURI;

        insuranceRate = _insuranceRate;

        admin = _admin;

        adr = _adr;

        wETH = _wETH;

        accessManager = _accessManager;

        emit BaseURIset(address(0), _baseURI);

        emit InsuranceRateSet(address(0), insuranceRate);

        emit AdminSet(address(0), _admin);

        emit AdrSet(address(0), _adr);
    }

    /// -----------------------------------------------------------------------
    /// Public Functions
    /// -----------------------------------------------------------------------

    function mint(
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data,
        string[] calldata _tokenURIs
    ) external payable {
        uint256 idsLength = ids.length;
        uint256 fee;

        // An array can't have a total length
        // larger than the max uint256 value.
        unchecked {
            fee = (idsLength * 1 ether * insuranceRate) / 1000;
        }

        if (fee != 0) require(msg.value == fee, "NOT_FEE");

        __batchMint(address(this), ids, amounts, data, _tokenURIs);
    }

    /// -----------------------------------------------------------------------
    /// Management Functions
    /// -----------------------------------------------------------------------

    function manageMint(
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data,
        string[] calldata _tokenURIs
    ) external payable {
        require(manager[msg.sender] || msg.sender == admin, "NOT_AUTHORIZED");

        __batchMint(admin, ids, amounts, data, _tokenURIs);
    }

    function manageBurn(
        address from,
        uint256[] calldata ids,
        uint256[] calldata amounts
    ) external payable {
        require(manager[msg.sender] || msg.sender == admin, "NOT_AUTHORIZED");

        _batchBurn(from, ids, amounts);
    }

    /// -----------------------------------------------------------------------
    /// TradingPost Functions
    /// -----------------------------------------------------------------------

    function setExtension(
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
        require(manager[msg.sender] || msg.sender == admin, "NOT_AUTHORIZED");
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

    function callExtension(
        uint256 trade,
        string calldata tokenUri,
        bytes calldata data
    ) external payable {
        require(
            trades[trade].tradeType != TradeType.UNAVAILABLE,
            "TRADE_UNAVAILABLE"
        );
        require(trades[trade].expiry > block.timestamp, "TRADE_EXPIRED");

        // Check if token paused
        uint256 length = trades[trade].ids.length;
        for (uint256 i; i < length; ) {
            require(paused[trades[trade].ids[i]], "TRADE_PAUSED");
            unchecked {
                ++i;
            }
        }

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

    function setManager(address to, bool approval) external payable onlyAdmin {
        manager[to] = approval;

        emit ManagerSet(msg.sender, to, approval);
    }

    function setBaseURI(string calldata _baseURI) external payable onlyAdmin {
        baseURI = _baseURI;

        emit BaseURIset(msg.sender, _baseURI);
    }

    function setTokenPause(uint256[] calldata ids, bool[] calldata pauses)
        external
        payable
        onlyAdmin
    {
        require(ids.length == pauses.length, "LENGTH_MISMATCH");

        for (uint256 i; i < ids.length; ) {
            paused[ids[i]] = pauses[i];

            unchecked {
                ++i;
            }
        }

        emit TokenPauseSet(msg.sender, ids, pauses);
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
    /// ADR Functions
    /// -----------------------------------------------------------------------

    function setAdr(address to) external payable onlyAdmin {
        adr = to;

        emit AdrSet(msg.sender, to);
    }

    function release(address to, uint256 amount) external payable {
        require(msg.sender == adr, "NOT_ADR");
        require(insurance >= amount, "OVERDRAFT");
        to._safeTransferETH(amount);
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

/// @title TradingPost Registry
/// @author KaliCo LLC
/// @notice Factory to deploy TradingPost contracts.
contract TradingPostRegistry is Multicall {
    event TradingPostRegistered(
        address indexed tradingPost,
        string name,
        string symbol,
        string baseURI,
        address indexed admin
    );

    function registerTradingPost(
        string calldata _name,
        string calldata _symbol,
        string calldata _baseURI,
        uint8 _insuranceRate,
        address _admin,
        address _adr,
        address _wETH,
        IKaliAccessManager _accessManager
    ) external payable {
        address tradingPost = address(
            new TradingPost{salt: keccak256(bytes(_name))}(
                _name,
                _symbol,
                _baseURI,
                _insuranceRate,
                _admin,
                _adr,
                _wETH,
                _accessManager
            )
        );
        emit TradingPostRegistered(
            tradingPost,
            _name,
            _symbol,
            _baseURI,
            _admin
        );
    }
}
