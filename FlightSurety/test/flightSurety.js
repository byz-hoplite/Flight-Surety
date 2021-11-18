
var Test = require('../config/testConfig.js');
// var BigNumber = require('../node_modules/bignumber.js');
var Web3 = require('web3');

const {
    BN,           // Big Number support
    constants,    // Common constants, like the zero address and largest integers
    expectEvent,  // Assertions for emitted events
    expectRevert, // Assertions for transactions that should fail
} = require('@openzeppelin/test-helpers');



contract('Flight Surety Tests', async (accounts) => {

    var config;
    before('setup contract', async () => {
        config = await Test.Config(accounts);
        // await config.flightSuretyData.authorizeCaller(config.flightSuretyApp.address);
    });

    /****************************************************************************************/
    /* Operations and Settings                                                              */
    /****************************************************************************************/

    it(`(multiparty) has correct initial isOperational() value`, async function () {

        // Get operating status
        let status = await config.flightSuretyData.isOperational.call();
        assert.equal(status, true, "Incorrect initial operating status value");

    });

    it(`(multiparty) can block access to setOperatingStatus() for non-Contract Owner account`, async function () {

        // Ensure that access is denied for non-Contract Owner account
        let accessDenied = false;
        try {
            await config.flightSuretyData.setOperatingStatus(false, { from: config.testAddresses[2] });
        }
        catch (e) {
            accessDenied = true;
        }
        assert.equal(accessDenied, true, "Access not restricted to Contract Owner");

    });

    it(`(multiparty) can allow access to setOperatingStatus() for Contract Owner account`, async function () {

        // Ensure that access is allowed for Contract Owner account
        let accessDenied = false;
        try {
            await config.flightSuretyData.setOperatingStatus(false);
        }
        catch (e) {
            accessDenied = true;
        }
        assert.equal(accessDenied, false, "Access not restricted to Contract Owner");

    });

    it(`(multiparty) can block access to functions using requireIsOperational when operating status is false`, async function () {

        await config.flightSuretyData.setOperatingStatus(false);

        let reverted = false;
        try {
            await config.flightSurety.setTestingMode(true);
        }
        catch (e) {
            reverted = true;
        }
        assert.equal(reverted, true, "Access not blocked for requireIsOperational");

        // Set it back for other tests to work
        await config.flightSuretyData.setOperatingStatus(true);

    });

    it('A registgered airline can register another Airline if numnber of registerd airlines is less than 4', async () => {

        // ARRANGE
        let newAirline = accounts[2];

        // ACT
        await expectRevert(
            config.flightSuretyApp.registerAirline(newAirline, { from: config.firstAirline }),
            "Calling contract is not authorized to access data"
        );

        // authorize app contract to access data contract
        await config.flightSuretyData.authorizeCaller(config.flightSuretyApp.address, { from: accounts[0] });

        // Try registering the airline again
        let registerResult = await config.flightSuretyApp.registerAirline(newAirline, { from: config.firstAirline });

        let result = await config.flightSuretyApp.isAirline.call(newAirline);

        // ASSERT
        assert.equal(result, true, "A registerd airline should be able to register another airline");

        await expectEvent(registerResult, "AirlineRegistered", {
            airline: newAirline,
            count: "2"
        });

    });


    it('Registration of fifth and subsequent airlines requires multi-party consensus of 50% of registered airlines', async () => {

        // ARRANGE
        let secondAirline = accounts[2];
        let thirdAirline = accounts[3];
        let fourthAirline = accounts[4];
        let fifthAirline = accounts[5];

        // ACT

        // three airlines can be registered by the first airline
        await expectRevert(
            config.flightSuretyApp.registerAirline(secondAirline, { from: config.firstAirline }),
            "Airline is already registered"
        );

        await config.flightSuretyApp.registerAirline(thirdAirline, { from: config.firstAirline });
        await config.flightSuretyApp.registerAirline(fourthAirline, { from: config.firstAirline });

        // fifth airline can't be registered by single airline
        await config.flightSuretyApp.registerAirline(fifthAirline, { from: config.firstAirline });

        // ASSERT
        assert.equal(await config.flightSuretyApp.isAirline.call(thirdAirline), true, "Third airline should be registered");
        assert.equal(await config.flightSuretyApp.isAirline.call(fourthAirline), true, "Fourth airline should be registered");
        assert.equal(await config.flightSuretyApp.isAirline.call(fifthAirline), false, "Fifth airline should not be registered");

        // Try registering airline from another registerd airline reaching 50% consensus
        let fifthRegistration = await config.flightSuretyApp.registerAirline(fifthAirline, { from: secondAirline });
        assert.equal(await config.flightSuretyApp.isAirline.call(fifthAirline), true, "Fifth airline should be registered");

        // EVENTS
        await expectEvent(fifthRegistration, "AirlineRegistered", {
            airline: fifthAirline,
            count: "5"
        });

    });

    
});
