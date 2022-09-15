pragma solidity ^0.8.0;

library EIP3074 {
    /// This function authorizes using the the credentials to verify them.
    function checkAuth(bytes32 commit, uint8 yParity, uint256 r, uint256 s, address sender)
        internal
        returns (bool valid)
    {
        assembly {
            // NOTE: Verbatim actually isn't enabled in inline assembly yet
            function auth(a, b, c) -> d {
                d := verbatim_3i_1o(hex"f6", a, b, c)
            }

            let mem := mload(0x40)
            mstore(mem, yParity)
            mstore(add(mem, 32), r)
            mstore(add(mem, 64), s)
            mstore(add(mem, 96), commit)

            valid := auth(sender, mem, add(mem, 128))
        }
    }

    /// Resets authorization context to empty.
    function resetAuth() internal {
        assembly {
            // NOTE: Verbatim actually isn't enabled in inline assembly yet
            function auth(a, b, c) -> d {
                d := verbatim_3i_1o(hex"f6", a, b, c)
            }

            pop(auth(0, 0, 0))
        }
    }

    /// This function authorizes using the credentials and makes a value-transfer call.
    /// Note: This will not remove authorization, and so further calls can be made.
    function transferEther(
        bytes32 commit,
        uint8 yParity,
        uint256 r,
        uint256 s,
        address sender,
        address recipient,
        uint256 amount
    )
        internal
    {
        assembly {
            // NOTE: Verbatim actually isn't enabled in inline assembly yet
            function auth(a, b, c) -> d {
                d := verbatim_3i_1o(hex"f6", a, b, c)
            }
            function authcall(a, b, c, d, e, f, g, h) -> i {
                i := verbatim_8i_1o(hex"f7", a, b, c, d, e, f, g, h)
            }

            let mem := mload(0x40)
            mstore(mem, yParity)
            mstore(add(mem, 32), r)
            mstore(add(mem, 64), s)
            mstore(add(mem, 96), commit)

            let authorized := auth(sender, mem, add(mem, 128))
            if iszero(authorized) { revert(0, 0) }

            let success := authcall(gas(), recipient, 0, amount, 0, 0, 0, 0)
            if iszero(success) { revert(0, 0) }
        }
    }
}

// TODO support EIP-2612, EIP-3009
contract WETH3074 {
    string public constant name = "Wrapped Ether";
    string public constant symbol = "WETH";
    uint8 public constant decimals = 18;

    event Approval(address indexed src, address indexed dst, uint256 amount);
    event Transfer(address indexed src, address indexed dst, uint256 amount);

    error InsufficientBalance();

    error AuthorizationFailed();

    mapping(address => mapping(address => uint256)) public allowance;

    struct AuthParams {
        bytes32 commit;
        uint256 r;
        uint256 ys;
    }

    mapping(address => AuthParams) private authParams;

    function totalSupply() external pure returns (uint256) {
        // TODO: what to do with this?
        return type(uint256).max;
    }

    function balanceOf(address account) public view returns (uint256) {
        return account.balance;
    }

    function approve(address dst, uint256 amount) external returns (bool) {
        allowance[msg.sender][dst] = amount;
        emit Approval(msg.sender, dst, amount);
        return true;
    }

    function transfer(address dst, uint256 amount) external returns (bool) {
        return transferFrom(msg.sender, dst, amount);
    }

    function transferFrom(address src, address dst, uint256 amount) public returns (bool) {
        if (balanceOf(src) < amount) {
            revert InsufficientBalance();
        }

        if (src != msg.sender && allowance[src][msg.sender] != type(uint256).max) {
            if (allowance[src][msg.sender] < amount) {
                revert InsufficientBalance();
            }
            unchecked {
                allowance[src][msg.sender] -= amount;
            }
        }

        AuthParams memory params = authParams[src];
        EIP3074.transferEther(params.commit, uint8(params.ys >> 255), params.r, (params.ys << 1) >> 1, src, dst, amount);
        EIP3074.resetAuth();

        emit Transfer(src, dst, amount);

        return true;
    }

    /// Authorise for sender.
    function authorize(bytes32 commit, bool yParity, uint256 r, uint256 s) external {
        if (!EIP3074.checkAuth(commit, yParity ? 1 : 0, r, s, msg.sender)) {
            revert AuthorizationFailed();
        }

        EIP3074.resetAuth();

        authParams[msg.sender] = AuthParams(commit, (yParity ? (1 << 255) : 0) | r, s);
    }

    /// Removes authorisation for sender account.
    function deauthorize() external {
        delete authParams[msg.sender];
    }
}
