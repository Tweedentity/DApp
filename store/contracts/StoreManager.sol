pragma solidity ^0.4.23;


import 'openzeppelin-solidity/contracts/lifecycle/Pausable.sol';
import 'openzeppelin-solidity/contracts/ownership/HasNoEther.sol';


contract StoreInterface {

  function getAppNickname()
  external
  constant returns (bytes32);


  function getAppId()
  external
  constant returns (uint);


  function getAddressLastUpdate(
    address _address
  )
  external
  constant returns (uint);


  function isUpgradable(
    address _address,
    string _uid
  )
  public
  constant returns (bool);


  function isUid(
    string _uid
  )
  public
  view
  returns (bool);


  function setIdentity(
    address _address,
    string _uid
  )
  external;


  function unsetIdentity(
    address _address
  )
  external;

}


/**
 * @title StoreManager
 * @author Francesco Sullo <francesco@sullo.co>
 * @dev Sets and removes tweedentities in the store,
 * adding more logic to the simple logic of the store
 */


contract StoreManager
is Pausable, HasNoEther
{

  string public fromVersion = "1.1.0";

  struct Store {
    StoreInterface store;
    address addr;
    bool active;
  }

  mapping(uint => Store) private __stores;
  uint public totalStores;

  mapping(uint => bytes32) public appNicknames32;
  mapping(uint => string) public appNicknames;
  mapping(string => uint) private __appIds;

  address public claimer;
  address public newClaimer;
  mapping(address => bool) public customerService;
  address[] private __customerServiceAddress;

  uint public upgradable = 0;
  uint public notUpgradableInStore = 1;
  uint public addressNotUpgradable = 2;

  uint public minimumTimeBeforeUpdate = 1 hours;



  // events


  event StoreSet(
    string appNickname,
    address indexed addr
  );


  event ClaimerSet(
    address indexed claimer,
    bool isNew
  );


  event StoreActive(
    string appNickname,
    address indexed store,
    bool active
  );


  event ClaimerSwitch(
    address indexed oldClaimer,
    address indexed newClaimer
  );


  event CustomerServiceSet(
    address indexed addr
  );


  event IdentityNotUpgradable(
    string appNickname,
    address indexed addr,
    string uid
  );


  event MinimumTimeBeforeUpdateChanged(
    uint _newMinimumTime
  );

  // config


  /**
   * @dev Sets a store to be used by the manager
   * @param _appNickname The nickname of the app for which the store's been configured
   * @param _address The address of the store
   */
  function setAStore(
    string _appNickname,
    address _address
  )
  public
  onlyOwner
  {
    require(bytes(_appNickname).length > 0);
    bytes32 _appNickname32 = keccak256(abi.encodePacked(_appNickname));
    require(_address != address(0));
    StoreInterface _store = StoreInterface(_address);
    require(_store.getAppNickname() == _appNickname32);
    uint _appId = _store.getAppId();
    require(appNicknames32[_appId] == 0x0);
    appNicknames32[_appId] = _appNickname32;
    appNicknames[_appId] = _appNickname;
    __appIds[_appNickname] = _appId;

    __stores[_appId] = Store(
      _store,
      _address,
      true
    );
    totalStores++;
    emit StoreSet(_appNickname, _address);
    emit StoreActive(_appNickname, _address, true);
  }


  /**
   * @dev Sets the claimer which will verify the ownership and call to set a tweedentity
   * @param _address Address of the claimer
   */
  function setClaimer(
    address _address
  )
  public
  onlyOwner
  {
    require(_address != address(0));
    claimer = _address;
    emit ClaimerSet(_address, false);
  }


  /**
   * @dev Sets a new claimer during updates
   * @param _address Address of the new claimer
   */
  function setNewClaimer(
    address _address
  )
  public
  onlyOwner
  {
    require(_address != address(0) && claimer != address(0));
    newClaimer = _address;
    emit ClaimerSet(_address, true);
  }


  /**
  * @dev Sets new manager
  */
  function switchClaimerAndRemoveOldOne()
  external
  onlyOwner
  {
    require(newClaimer != address(0));
    emit ClaimerSwitch(claimer, newClaimer);
    claimer = newClaimer;
    newClaimer = address(0);
  }


  /**
   * @dev Sets a wallet as customer service to perform emergency removal of wrong, abused, squatted tweedentities (due, for example, to hacking of the Twitter account)
   * @param _address The customer service wallet
   * @param _status The status (true is set, false is unset)
   */
  function setCustomerService(
    address _address,
    bool _status
  )
  public
  onlyOwner
  {
    require(_address != address(0));
    customerService[_address] = _status;
    bool found;
    for (uint i = 0; i < __customerServiceAddress.length; i++) {
      if (__customerServiceAddress[i] == _address) {
        found = true;
        break;
      }
    }
    if (!found) {
      __customerServiceAddress.push(_address);
    }
    emit CustomerServiceSet(_address);
  }



  /**
   * @dev Unable/disable a store
   * @param _appNickname The store to be enabled/disabled
   * @param _active A bool to unable (true) or disable (false)
   */
  function activateStore(
    string _appNickname,
    bool _active
  )
  public
  onlyOwner
  {
    uint _appId = __appIds[_appNickname];
    require(__stores[_appId].active != _active);
    __stores[_appId] = Store(
      __stores[_appId].store,
      __stores[_appId].addr,
      _active
    );
    emit StoreActive(_appNickname, __stores[_appId].addr, _active);
  }



  //modifiers


  modifier onlyClaimer() {
    require(msg.sender == claimer || (newClaimer != address(0) && msg.sender == newClaimer));
    _;
  }


  modifier onlyCustomerService() {
    require(msg.sender == owner || customerService[msg.sender] == true);
    _;
  }


  modifier whenStoreSet(
    uint _appId
  ) {
    require(appNicknames32[_appId] != 0x0);
    _;
  }



  // internal getters


  function __getStore(
    uint _appId
  )
  internal
  constant returns (StoreInterface)
  {
    return __stores[_appId].store;
  }



  // helpers


  function isAddressUpgradable(
    StoreInterface _store,
    address _address
  )
  internal
  constant returns (bool)
  {
    uint lastUpdate = _store.getAddressLastUpdate(_address);
    return lastUpdate == 0 || now >= lastUpdate + minimumTimeBeforeUpdate;
  }


  function isUpgradable(
    StoreInterface _store,
    address _address,
    string _uid
  )
  internal
  constant returns (bool)
  {
    if (!_store.isUpgradable(_address, _uid) || !isAddressUpgradable(_store, _address)) {
      return false;
    }
    return true;
  }



  // getters


  /**
   * @dev Gets the app-id associated to a nickname
   * @param _appNickname The nickname of a configured app
   */
  function getAppId(
    string _appNickname
  )
  external
  constant returns (uint) {
    return __appIds[_appNickname];
  }


  /**
   * @dev Allows other contracts to check if a store is set
   * @param _appNickname The nickname of a configured app
   */
  function isStoreSet(
    string _appNickname
  )
  public
  constant returns (bool){
    return __appIds[_appNickname] != 0;
  }


  /**
   * @dev Allows other contracts to check if a store is active
   * @param _appId The id of a configured app
   */
  function isStoreActive(
    uint _appId
  )
  public
  constant returns (bool){
    return __stores[_appId].active;
  }


  /**
   * @dev Return a numeric code about the upgradability of a couple wallet-uid in a certain app
   * @param _appId The id of the app
   * @param _address The address of the wallet
   * @param _uid The user-id
   */
  function getUpgradability(
    uint _appId,
    address _address,
    string _uid
  )
  external
  constant returns (uint)
  {
    StoreInterface _store = __getStore(_appId);
    if (!_store.isUpgradable(_address, _uid)) {
      return notUpgradableInStore;
    } else if (!isAddressUpgradable(_store, _address)) {
      return addressNotUpgradable;
    } else {
      return upgradable;
    }
  }


  /**
   * @dev Returns the address of a store
   * @param _appNickname The app nickname
   */
  function getStoreAddress(
    string _appNickname
  )
  external
  constant returns (address) {
    return __stores[__appIds[_appNickname]].addr;
  }


  /**
   * @dev Returns the address of a store
   * @param _appId The app id
   */
  function getStoreAddressById(
    uint _appId
  )
  external
  constant returns (address) {
    return __stores[_appId].addr;
  }


  /**
   * @dev Returns the address of any customerService account
   */
  function getCustomerServiceAddress()
  external
  constant returns (address[]) {
    return __customerServiceAddress;
  }



  // primary methods


  /**
   * @dev Sets a new identity
   * @param _appId The id of the app
   * @param _address The address of the wallet
   * @param _uid The user-id
   */
  function setIdentity(
    uint _appId,
    address _address,
    string _uid
  )
  external
  onlyClaimer
  whenStoreSet(_appId)
  whenNotPaused
  {
    require(_address != address(0));

    StoreInterface _store = __getStore(_appId);
    require(_store.isUid(_uid));

    if (isUpgradable(_store, _address, _uid)) {
      _store.setIdentity(_address, _uid);
    } else {
      emit IdentityNotUpgradable(appNicknames[_appId], _address, _uid);
    }
  }


  /**
   * @dev Unsets an existent identity
   * @param _appId The id of the app
   * @param _address The address of the wallet
   */
  function unsetIdentity(
    uint _appId,
    address _address
  )
  external
  onlyCustomerService
  whenStoreSet(_appId)
  whenNotPaused
  {
    StoreInterface _store = __getStore(_appId);
    _store.unsetIdentity(_address);
  }


  /**
   * @dev Allow the sender to unset its existent identity
   * @param _appId The id of the app
   */
  function unsetMyIdentity(
    uint _appId
  )
  external
  whenStoreSet(_appId)
  whenNotPaused
  {
    StoreInterface _store = __getStore(_appId);
    _store.unsetIdentity(msg.sender);
  }


  /**
   * @dev Update the minimum time before allowing a wallet to update its data
   * @param _newMinimumTime The new minimum time in seconds
   */
  function changeMinimumTimeBeforeUpdate(
    uint _newMinimumTime
  )
  external
  onlyOwner
  {
    minimumTimeBeforeUpdate = _newMinimumTime;
    emit MinimumTimeBeforeUpdateChanged(_newMinimumTime);
  }

}
