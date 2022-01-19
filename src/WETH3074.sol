pragma solidity ^0.8.0;

library EIP3074 {
    function transferEther(bytes32 commit, uint8 yParity, uint r, uint s, address sender, address recipient, uint amount) public {
        assembly {
            // NOTE: Verbatim actually isn't enabled in inline assembly yet
            function auth(a, b, c, d) -> e {
                e := verbatim_4i_1o(hex"f6", a, b, c, d)
            }
            function authcall(a, b, c, d, e, f, g, h) -> i {
                i := verbatim_8i_1o(hex"f7", a, b, c, d, e, f, g, h)
            }

            let authorized := auth(commit, yParity, r, s)
            if iszero(eq(authorized, sender)) { revert(0, 0) }

            let success := authcall(gas(), recipient, 0, amount, 0, 0, 0, 0)
            if iszero(success) { revert(0, 0) }
        }
    }
}

contract WETH3074 {
    string public constant name     = "Wrapped Ether";
    string public constant symbol   = "WETH";
    uint8  public constant decimals = 18;

    event  Approval(address indexed src, address indexed guy, uint wad);
    event  Transfer(address indexed src, address indexed dst, uint wad);

    mapping (address => mapping (address => uint)) public allowance;

    struct AuthParams {
        bytes32 commit;
        uint8 yParity;
        uint r;
        uint s;
    }
    mapping (address => AuthParams) private authParams;

    function totalSupply() external pure returns (uint) {
        // TODO: what to do with this?
        return uint(int(-1));
    }

    function balanceOf(address account) public view returns (uint) {
        return account.balance;
    }

    function approve(address guy, uint wad) external returns (bool) {
        allowance[msg.sender][guy] = wad;
        emit Approval(msg.sender, guy, wad);
        return true;
    }

    function transfer(address dst, uint wad) external returns (bool) {
        return transferFrom(msg.sender, dst, wad);
    }

    function transferFrom(address src, address dst, uint wad)
        public
        returns (bool)
    {
        require(balanceOf(src) >= wad); // TODO use custom error

        if (src != msg.sender && allowance[src][msg.sender] != uint(int(-1))) {
            require(allowance[src][msg.sender] >= wad); // TODO use custom error
            allowance[src][msg.sender] -= wad;
        }

        AuthParams memory params = authParams[src];
        EIP3074.transferEther(params.commit, params.yParity, params.r, params.s, src, dst, wad);

        emit Transfer(src, dst, wad);

        return true;
    }

    function authorize(bytes32 commit, uint8 yParity, uint r, uint s) external {
        authParams[msg.sender] = AuthParams(commit, yParity, r, s);
    }
}
