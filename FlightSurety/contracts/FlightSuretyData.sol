// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9; // ^0.8.0 ensures SafeMath builtin

import "../node_modules/@openzeppelin/contracts/utils/math/SafeMath.sol";

contract FlightSuretyData {
    using SafeMath for uint256;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    address private contractOwner; // Account used to deploy contract
    bool private operational = true; // Blocks all state changes throughout the contract if false

    mapping(address => bool) private authorizedCallers; // App contract addresses authorized to call this data contract

    // Airlines
    struct Airline {
        bool isRegistered;
        uint256 funds;
    }
    uint256 registeredAirlinesCount = 1;
    uint256 fundedAirlinesCount = 1;
    mapping(address => Airline) private airlines;

    // Flights
    struct Flight {
        address airline;
        string flightNumber;
        uint256 departureTime;
        string departureLoc;
        string arrivalLoc;
        uint8 statusCode;
    }
    mapping(bytes32 => Flight) public flights;
    bytes32[] public registeredFlights;

    // Insurance
    struct FlightInsurance {
        address passenger;
        uint256 amount;
        bool isRefunded;
    }

    // Flight Insurance
    mapping(bytes32 => FlightInsurance[]) public flightInsurances;

    // Passenger Insurance Claims
    mapping(address => uint256) public claims;

    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/

    /**
     * @dev Constructor
     *      The deploying account becomes contractOwner
     */
    constructor(address airlineAddress) {
        contractOwner = msg.sender;
        airlines[airlineAddress] = Airline(true, 0);
    }

    /********************************************************************************************/
    /*                                       FUNCTION MODIFIERS                                 */
    /********************************************************************************************/

    // Modifiers help avoid duplication of code. They are typically used to validate something
    // before a function is allowed to be executed.

    /**
     * @dev Modifier that requires the "operational" boolean variable to be "true"
     *      This is used on all state changing functions to pause the contract in
     *      the event there is an issue that needs to be fixed
     */
    modifier requireIsOperational() {
        require(operational, "Contract is currently not operational");
        _; // All modifiers require an "_" which indicates where the function body will be added
    }

    /**
     * @dev Modifier that requires the "ContractOwner" account to be the function caller
     */
    modifier requireContractOwner() {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

    // airline modifiers
    modifier requireNotAlreadyRegistered(address airline) {
        require(
            !airlines[airline].isRegistered,
            "Airline is already registered"
        );
        _;
    }

    modifier requireRegistered(address airline) {
        require(airlines[airline].isRegistered, "Airline is not registered");
        _;
    }

    modifier requireFunded(address airline) {
        require(
            airlines[airline].funds >= 10 ether,
            "Airline is not sufficiently contributed to the funds"
        );
        _;
    }

    modifier requireAuthorizedCaller() {
        require(
            authorizedCallers[msg.sender],
            "Calling contract is not authorized to access data"
        );
        _;
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    /**
     * @dev Get operating status of contract
     *
     * @return A bool that is the current operating status
     */
    function isOperational() public view returns (bool) {
        return operational;
    }

    /**
     * @dev Sets contract operations on/off
     *
     * When operational mode is disabled, all write transactions except for this one will fail
     */
    function setOperatingStatus(bool mode) external requireContractOwner {
        operational = mode;
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

    function authorizeCaller(address contractAddress)
        external
        requireContractOwner
    {
        authorizedCallers[contractAddress] = true;
    }

    function deauthorizeContract(address contractAddress)
        external
        requireContractOwner
    {
        delete authorizedCallers[contractAddress];
    }

    /**
     * @dev Add an airline to the registration queue
     *      Can only be called from FlightSuretyApp contract
     *
     */
    function registerAirline(address airline)
        external
        requireIsOperational
        requireAuthorizedCaller
        requireNotAlreadyRegistered(airline)
    {
        airlines[airline] = Airline(true, 0);
        registeredAirlinesCount += 1;
    }

    function isAirlineRegistered(address airline) external view returns (bool) {
        return airlines[airline].isRegistered;
    }

    function isFunded(address airline) external view returns (bool) {
        uint256 funds = airlines[airline].funds;
        return funds >= (10 ether);
    }

    function getFunds(address airline)
        external
        view
        returns (uint256 amount)
    {
        return airlines[airline].funds;
    }

    function getRegisteredAirlinesCount() external view returns (uint256) {
        return registeredAirlinesCount;
    }

    /**
     * @dev Buy insurance for a flight
     *
     */
    function buy() external payable {}

    /**
     *  @dev Credits payouts to insurees
     */
    function creditInsurees() external pure {}

    /**
     *  @dev Transfers eligible payout funds to insuree
     *
     */
    function pay() external pure {}

    /**
     * @dev Initial funding for the insurance. Unless there are too many delayed flights
     *      resulting in insurance payouts, the contract should be self-sustaining
     *
     */
    function fund(address airline, uint256 amount)
        public
        payable
        requireIsOperational
        requireRegistered(airline)
    {
        airlines[airline].funds += amount;
    }

    function getFlightKey(
        address airline,
        string memory flight,
        uint256 timestamp
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    /**
     * @dev Fallback function for funding smart contract.
     *
     */
    fallback() external payable {
        fund(msg.sender, msg.value);
    }

    receive() external payable {
        // custom function code
    }
}
