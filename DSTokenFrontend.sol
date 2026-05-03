// Flattened DSTokenFrontend from dapphub/dappsys @ tag 0.1.2 (commit 8ddd3f3)
// Original imports (in dependency order):
//   util/true.sol
//   util/false.sol
//   auth/enum.sol
//   auth/events.sol
//   auth/authority.sol
//   auth/authorized.sol
//   auth/util.sol
//   auth.sol
//   token/erc20.sol
//   token/event_callback.sol
//   token/token.sol
//   util/safety.sol
//   data/balance_db.sol
//   data/approval_db.sol
//   token/controller.sol
//   token/frontend.sol
//   dapple/debug.sol

// ============== util/true.sol ==============
contract DSTrueFallback {
    function() returns (bool) {
        return true;
    }
}

// ============== util/false.sol ==============
contract DSFalseFallback {
    function() returns (bool) {
        return false;
    }
}

// ============== auth/enum.sol ==============
contract DSAuthModesEnum {
    enum DSAuthModes {
        Owner,
        Authority
    }
}

// ============== auth/events.sol ==============
contract DSAuthorizedEvents is DSAuthModesEnum {
    event DSAuthUpdate( address indexed auth, DSAuthModes indexed mode );
}

// ============== auth/authority.sol ==============
contract DSAuthority {
    function canCall( address caller
                    , address callee
                    , bytes4 sig )
             constant
             returns (bool);
}

contract AcceptingAuthority is DSTrueFallback {}
contract RejectingAuthority is DSFalseFallback {}

// ============== auth/authorized.sol ==============
contract DSAuthorized is DSAuthModesEnum, DSAuthorizedEvents
{
    modifier auth() {
        if( isAuthorized() ) {
            _
        } else {
            throw;
        }
    }
    modifier try_auth() {
        if( isAuthorized() ) {
            _
        }
    }
    function isAuthorized() internal returns (bool);
    function updateAuthority(address, DSAuthModes);
}

// ============== auth/util.sol ==============
contract DSAuthUtils is DSAuthModesEnum {
    function setOwner( DSAuthorized what, address owner ) internal {
        what.updateAuthority( owner, DSAuthModes.Owner );
    }
    function setAuthority( DSAuthorized what, DSAuthority authority ) internal {
        what.updateAuthority( authority, DSAuthModes.Authority );
    }
}

// ============== auth.sol ==============
contract DSAuth is DSAuthorized {}
contract DSAuthUser is DSAuthUtils {}

// ============== token/erc20.sol ==============
contract ERC20Stateless {
    function totalSupply() constant returns (uint supply);
    function balanceOf( address who ) constant returns (uint value);
    function allowance(address owner, address spender) constant returns (uint _allowance);
}
contract ERC20Stateful {
    function transfer( address to, uint value) returns (bool ok);
    function transferFrom( address from, address to, uint value) returns (bool ok);
    function approve(address spender, uint value) returns (bool ok);
}
contract ERC20Events {
    event Transfer(address indexed from, address indexed to, uint value);
    event Approval( address indexed owner, address indexed spender, uint value);
}
contract ERC20 is ERC20Stateless, ERC20Stateful, ERC20Events {}

// ============== token/event_callback.sol ==============
contract DSTokenEventCallback {
    function emitTransfer( address from, address to, uint amount );
    function emitApproval( address holder, address spender, uint amount );
}

// ============== token/token.sol ==============
contract DSToken is ERC20 {}

// ============== util/safety.sol ==============
contract DSSafeAddSub {
    function safeToAdd(uint a, uint b) internal returns (bool) {
        return (a + b >= a);
    }
    function safeAdd(uint a, uint b) internal returns (uint) {
        if (!safeToAdd(a, b)) throw;
        return a + b;
    }

    function safeToSubtract(uint a, uint b) internal returns (bool) {
        return (b <= a);
    }
    function safeSub(uint a, uint b) internal returns (uint) {
        if (!safeToSubtract(a, b)) throw;
        return a - b;
    }
}

// ============== data/balance_db.sol ==============
contract DSBalanceDBEvents {
    event BalanceUpdate( address indexed who, uint new_amount );
}

contract DSBalanceDB is DSAuth
                      , DSSafeAddSub
                      , DSBalanceDBEvents
{
    uint _supply;
    mapping( address => uint )  _balances;

    function getSupply()
             constant
             returns (uint)
    {
        return _supply;
    }
    function getBalance( address who )
             constant
             returns (uint)
    {
        return _balances[who];
    }
    function setBalance( address who, uint new_balance )
             auth()
    {
        var old_balance = _balances[who];
        if( new_balance <= old_balance ) {
            _supply = safeSub( _supply, old_balance - new_balance );
        } else {
            _supply = safeAdd( _supply, new_balance - old_balance );
        }
        _balances[who] = new_balance;
        BalanceUpdate( who, new_balance );
    }
    function addBalance( address to, uint amount )
             auth()
    {
        _supply = safeAdd( _supply, amount );
        _balances[to] = safeAdd( _balances[to], amount );
        BalanceUpdate( to, _balances[to] );
    }
    function subBalance( address from, uint amount )
             auth()
    {
        _supply = safeSub( _supply, amount );
        _balances[from] = safeSub( _balances[from], amount );
        BalanceUpdate( from, _balances[from] );
    }
    function moveBalance( address from, address to, uint amount )
             auth()
    {
        _balances[from] = safeSub( _balances[from], amount );
        _balances[to] = safeAdd( _balances[to], amount );
        BalanceUpdate( from, _balances[from] );
        BalanceUpdate( to, _balances[to] );
    }
}

// ============== data/approval_db.sol ==============
contract DSApprovalDBEvents {
    event Approval( address indexed owner, address indexed spender, uint value );
}

contract DSApprovalDB is DSAuth, DSApprovalDBEvents {
    mapping(address => mapping( address=>uint)) _approvals;

    function setApproval( address holder, address spender, uint amount )
             auth()
    {
        _approvals[holder][spender] = amount;
        Approval( holder, spender, amount );
    }
    function getApproval( address holder, address spender )
             returns (uint amount )
    {
        return _approvals[holder][spender];
    }
}

// ============== token/controller.sol ==============
contract DSTokenControllerType is ERC20Stateless
                                , DSSafeAddSub
                                , DSAuthUser
{
    function transfer( address _caller, address to, uint value) returns (bool ok);
    function transferFrom( address _caller, address from, address to, uint value) returns (bool ok);
    function approve( address _caller, address spender, uint value) returns (bool ok);

    function getFrontend() constant returns (DSTokenFrontend);
    function setFrontend( DSTokenFrontend frontend );
    function setBalanceDB( DSBalanceDB new_db );
    function getBalanceDB() constant returns (DSBalanceDB);
    function setApprovalDB( DSApprovalDB new_db );
    function getApprovalDB() constant returns (DSApprovalDB);
}

contract DSTokenController is DSTokenControllerType
                            , DSAuth
{
    DSBalanceDB                _balances;
    DSApprovalDB               _approvals;
    DSTokenFrontend            _frontend;

    function DSTokenController( DSTokenFrontend frontend, DSBalanceDB baldb, DSApprovalDB apprdb ) {
        _frontend = frontend;
        _balances = baldb;
        _approvals = apprdb;
    }
    function getFrontend() constant returns (DSTokenFrontend) {
        return _frontend;
    }
    function getApprovalDB() constant returns (DSApprovalDB) {
        return _approvals;
    }
    function getBalanceDB() constant returns (DSBalanceDB) {
        return _balances;
    }
    function setFrontend( DSTokenFrontend frontend )
             auth()
    {
        _frontend = frontend;
    }
    function setBalanceDB( DSBalanceDB new_db )
             auth()
    {
        _balances = new_db;
    }
    function setApprovalDB( DSApprovalDB new_db )
             auth()
    {
        _approvals = new_db;
    }

    function totalSupply() constant returns (uint supply) {
        return _balances.getSupply();
    }
    function balanceOf( address who ) constant returns (uint amount) {
        return _balances.getBalance( who );
    }
    function allowance(address owner, address spender) constant returns (uint _allowance) {
        return _approvals.getApproval(owner, spender);
    }

    function transfer(address _caller, address to, uint value)
             auth()
             returns (bool ok)
    {
        if( _balances.getBalance(_caller) < value ) {
            throw;
        }
        if( !safeToAdd(_balances.getBalance(to), value) ) {
            throw;
        }
        _balances.moveBalance(_caller, to, value);
        _frontend.emitTransfer( _caller, to, value );
        return true;
    }
    function transferFrom(address _caller, address from, address to, uint value)
             auth()
             returns (bool)
    {
        var from_balance = _balances.getBalance( from );
        if( _balances.getBalance(from) < value ) {
            throw;
        }

        var allowance = _approvals.getApproval( from, _caller );
        if( allowance < value ) {
            throw;
        }

        if( !safeToAdd(_balances.getBalance(to), value) ) {
            throw;
        }
        _approvals.setApproval( from, _caller, allowance - value );
        _balances.moveBalance( from, to, value);
        _frontend.emitTransfer( from, to, value );
        return true;
    }
    function approve( address _caller, address spender, uint value)
             auth()
             returns (bool)
    {
        _approvals.setApproval( _caller, spender, value );
        _frontend.emitApproval( _caller, spender, value);
    }
}

// ============== dapple/debug.sol ==============
contract Debug {
    event logs(bytes val);

    event log_named_decimal_int(bytes32 key, int val, uint decimals);
    event log_named_decimal_uint(bytes32 key, uint val, uint decimals);

    event log_bool(bool val);
    event log_named_bool(bytes32 key, bool val);
    event log_uint(uint val);
    event log_named_uint(bytes32 key, uint val);
    event log_int(int val);
    event log_named_int(bytes32 key, int val);
    event log_address(address val);
    event log_named_address(bytes32 key, address val);
    event log_bytes(bytes val);
    event log_named_bytes(bytes32 key, bytes val);
    event log_bytes1(bytes1 val);
    event log_named_bytes1(bytes32 key, bytes1 val);
    event log_bytes2(bytes2 val);
    event log_named_bytes2(bytes32 key, bytes2 val);
    event log_bytes3(bytes3 val);
    event log_named_bytes3(bytes32 key, bytes3 val);
    event log_bytes4(bytes4 val);
    event log_named_bytes4(bytes32 key, bytes4 val);
    event log_bytes5(bytes5 val);
    event log_named_bytes5(bytes32 key, bytes5 val);
    event log_bytes6(bytes6 val);
    event log_named_bytes6(bytes32 key, bytes6 val);
    event log_bytes7(bytes7 val);
    event log_named_bytes7(bytes32 key, bytes7 val);
    event log_bytes8(bytes8 val);
    event log_named_bytes8(bytes32 key, bytes8 val);
    event log_bytes9(bytes9 val);
    event log_named_bytes9(bytes32 key, bytes9 val);
    event log_bytes10(bytes10 val);
    event log_named_bytes10(bytes32 key, bytes10 val);
    event log_bytes11(bytes11 val);
    event log_named_bytes11(bytes32 key, bytes11 val);
    event log_bytes12(bytes12 val);
    event log_named_bytes12(bytes32 key, bytes12 val);
    event log_bytes13(bytes13 val);
    event log_named_bytes13(bytes32 key, bytes13 val);
    event log_bytes14(bytes14 val);
    event log_named_bytes14(bytes32 key, bytes14 val);
    event log_bytes15(bytes15 val);
    event log_named_bytes15(bytes32 key, bytes15 val);
    event log_bytes16(bytes16 val);
    event log_named_bytes16(bytes32 key, bytes16 val);
    event log_bytes17(bytes17 val);
    event log_named_bytes17(bytes32 key, bytes17 val);
    event log_bytes18(bytes18 val);
    event log_named_bytes18(bytes32 key, bytes18 val);
    event log_bytes19(bytes19 val);
    event log_named_bytes19(bytes32 key, bytes19 val);
    event log_bytes20(bytes20 val);
    event log_named_bytes20(bytes32 key, bytes20 val);
    event log_bytes21(bytes21 val);
    event log_named_bytes21(bytes32 key, bytes21 val);
    event log_bytes22(bytes22 val);
    event log_named_bytes22(bytes32 key, bytes22 val);
    event log_bytes23(bytes23 val);
    event log_named_bytes23(bytes32 key, bytes23 val);
    event log_bytes24(bytes24 val);
    event log_named_bytes24(bytes32 key, bytes24 val);
    event log_bytes25(bytes25 val);
    event log_named_bytes25(bytes32 key, bytes25 val);
    event log_bytes26(bytes26 val);
    event log_named_bytes26(bytes32 key, bytes26 val);
    event log_bytes27(bytes27 val);
    event log_named_bytes27(bytes32 key, bytes27 val);
    event log_bytes28(bytes28 val);
    event log_named_bytes28(bytes32 key, bytes28 val);
    event log_bytes29(bytes29 val);
    event log_named_bytes29(bytes32 key, bytes29 val);
    event log_bytes30(bytes30 val);
    event log_named_bytes30(bytes32 key, bytes30 val);
    event log_bytes31(bytes31 val);
    event log_named_bytes31(bytes32 key, bytes31 val);
    event log_bytes32(bytes32 val);
    event log_named_bytes32(bytes32 key, bytes32 val);

    event _log_gas_use(uint gas);

    modifier logs_gas() {
        uint _start_gas = msg.gas;
        _
        _log_gas_use(_start_gas - msg.gas);
    }
}

// ============== token/frontend.sol ==============
contract DSTokenFrontend is DSToken
                          , DSTokenEventCallback
                          , DSAuth
{
    function updateAuthority( address new_authority, DSAuthModes mode )
             auth()
    {
        _authority = DSAuthority(new_authority);
        _auth_mode = mode;
        DSAuthUpdate( new_authority, mode );
    }
    function setController( DSTokenController controller )
             auth()
    {
        _controller = controller;
    }
    DSAuthModes  public _auth_mode;
    DSAuthority  public _authority;
    DSTokenController _controller;
    function isAuthorized() internal returns (bool is_authorized) {
        if( _auth_mode == DSAuthModes.Owner ) {
            return msg.sender == address(_authority);
        }
        if( _auth_mode == DSAuthModes.Authority ) {
            return _authority.canCall( msg.sender, address(this), msg.sig );
        }
        throw;
    }
    function DSTokenFrontend() {
        _authority = DSAuthority(msg.sender);
        _auth_mode = DSAuthModes.Owner;
        DSAuthUpdate( msg.sender, DSAuthModes.Owner );
    }
    function getController() constant returns (DSTokenController controller) {
        return _controller;
    }

    function emitTransfer( address from, address to, uint amount )
             auth()
    {
        Transfer( from, to, amount );
    }
    function emitApproval( address holder, address spender, uint amount )
             auth()
    {
        Approval( holder, spender, amount );
    }

    function totalSupply() constant returns (uint supply) {
        return _controller.totalSupply();
    }
    function balanceOf( address who ) constant returns (uint value) {
        return _controller.balanceOf( who );
    }
    function allowance(address owner, address spender) constant returns (uint _allowance) {
        return _controller.allowance( owner, spender );
    }

    function transfer( address to, uint value) returns (bool ok) {
        return _controller.transfer( msg.sender, to, value );
    }
    function transferFrom( address from, address to, uint value) returns (bool ok) {
        return _controller.transferFrom( msg.sender, from, to, value );
    }
    function approve(address spender, uint value) returns (bool ok) {
        return _controller.approve( msg.sender, spender, value );
    }
}
