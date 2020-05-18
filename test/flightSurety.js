var Test = require('../config/testConfig.js');
var BigNumber = require('bignumber.js');
var Web3 = require('web3');

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
      try 
      {
          await config.flightSuretyData.setOperatingStatus(false, { from: config.testAddresses[2] });
      }
      catch(e) {
          accessDenied = true;
      }
      assert.equal(accessDenied, true, "Access not restricted to Contract Owner");
            
  });

  it(`(multiparty) can allow access to setOperatingStatus() for Contract Owner account`, async function () {

      // Ensure that access is allowed for Contract Owner account
      let accessDenied = false;
      try 
      {
          await config.flightSuretyData.setOperatingStatus(false);
      }
      catch(e) {
          accessDenied = true;
      }
      assert.equal(accessDenied, false, "Access not restricted to Contract Owner");
      
  });

  it(`(multiparty) can block access to functions using requireIsOperational when operating status is false`, async function () {

      await config.flightSuretyData.setOperatingStatus(false);

      let reverted = false;
      try 
      {
          await config.flightSurety.setTestingMode(true);
      }
      catch(e) {
          reverted = true;
      }
      assert.equal(reverted, true, "Access not blocked for requireIsOperational");      

      // Set it back for other tests to work
      await config.flightSuretyData.setOperatingStatus(true);

  });

  it("(airline) first Airline registered on contract deployment", async () => {
    // ARRANGE
    const registered = await config.flightSuretyData.isAirlineRegistered.call(config.firstAirline);

    // ASSERT
    assert.equal(registered, true, "First Aitline was not registered.");
  });

  it('(airline) cannot register an Airline using registerAirline() if it is not funded', async () => {
    
    // ARRANGE
    let newAirline = accounts[2];

    // ACT
    try {
        await config.flightSuretyApp.registerAirline(newAirline, {from: config.firstAirline});
    }
    catch(e) {

    }
    let result = await config.flightSuretyData.isAirlineRegistered.call(newAirline); 

    // ASSERT
    assert.equal(result, false, "Airline should not be able to register another airline if it hasn't provided funding");

  });

  it('(airline) can register an Airline using registerAirline() when offered seed funding', async () => {
    // ARRANGE
    const seed_fund = await config.flightSuretyApp.AIRLINE_FUND.call();
    const airline2 = accounts[2];
    const airline3 = accounts[3];
    const airline4 = accounts[4];
    // ACT
    try {
        await config.flightSuretyApp.fundAirline({
          from: config.firstAirline,
          value: seed_fund.toString(),
          gasPrice: 0
        });
      }
      catch(e) {
        console.log(e);
    }

    try {
      await config.flightSuretyApp.registerAirline(airline2, {
        from: config.firstAirline
      });

      await config.flightSuretyApp.registerAirline(airline3, {
        from: config.firstAirline
      });

      await config.flightSuretyApp.registerAirline(airline4, {
        from: config.firstAirline
      });
    }
    catch(e) {
      console.log(e);
    }

    // ASSERT
    const funded = await config.flightSuretyData.isAirlineFunded.call(config.firstAirline);
    const airline2Registered = await config.flightSuretyData.isAirlineRegistered.call(airline2);
    const airline3Registered = await config.flightSuretyData.isAirlineRegistered.call(airline3);
    const airline4Registered = await config.flightSuretyData.isAirlineRegistered.call(airline4);
    assert.equal(funded, true, "Airline seed funding not accepted.");
    assert.equal(airline2Registered, true, "Funded Airline unable to register new Airline");
    assert.equal(airline3Registered, true, "Funded Airline unable to register new Airline");
    assert.equal(airline4Registered, true, "Funded Airline unable to register new Airline");
  });

  it('(airline) can register new airline via multiparty consensus mechanism', async () => {
    // ARRANGE
    const seed_fund = await config.flightSuretyApp.AIRLINE_FUND.call();
    const airline2 = accounts[2];
    const airline3 = accounts[3];
    const airline4 = accounts[4];
    const airline5 = accounts[5];

    // ACT
    try {
        await config.flightSuretyApp.fundAirline({
          from: airline2,
          value: seed_fund.toString(),
          gasPrice: 0
        });
      }
      catch(e) {
        console.log(e);
    }

    try {
        await config.flightSuretyApp.fundAirline({
          from: airline3,
          value: seed_fund.toString(),
          gasPrice: 0
        });
      }
      catch(e) {
        console.log(e);
    }

    try {
        await config.flightSuretyApp.fundAirline({
          from: airline4,
          value: seed_fund.toString(),
          gasPrice: 0
        });
      }
      catch(e) {
        console.log(e);
    }

    try {
        await config.flightSuretyApp.registerAirline(airline5, {
          from: config.firstAirline
        });

        await config.flightSuretyApp.registerAirline(airline5, {
          from: airline2
        });

        await config.flightSuretyApp.registerAirline(airline5, {
          from: airline3
        });
      }
      catch(e) {
        console.log(e);
    }

    // ASSERT
    const funded2 = await config.flightSuretyData.isAirlineFunded.call(airline2);
    const funded3 = await config.flightSuretyData.isAirlineFunded.call(airline3);
    const funded4 = await config.flightSuretyData.isAirlineFunded.call(airline4);
    const airline5Registered = await config.flightSuretyData.isAirlineRegistered.call(airline5);
    assert.equal(funded2, true, "Airline seed funding not accepted.");
    assert.equal(funded3, true, "Airline seed funding not accepted.");
    assert.equal(funded4, true, "Airline seed funding not accepted.");
    assert.equal(airline5Registered, false, "Airline unable to register via Multiparty Consensus");
  });

  it('(flight) can register new flight', async () => {
    // ARRANGE
    let reverted = false;
    const timestamp = Math.floor(Date.now() / 1000);
    const flightNumber = 'XTZ-184';

    // ACT
    try {
        await config.flightSuretyApp.registerFlight(config.firstAirline, flightNumber, timestamp);
    }
    catch(e) {
        reverted = true;
    }
      
    // ASSERT
    const flightRegistered = await config.flightSuretyData.isFlightRegistered(config.firstAirline, flightNumber, timestamp);
    assert.equal(flightRegistered, true, "Error: Unable to register flight.")
  });

  it('(payment) cannot purchase flight insurance greater than limit', async () => {
    // ARRANGE
    const payment = Web3.utils.toWei('2', "ether");
    const timestamp = Math.floor(Date.now() / 1000);
    const flightNumber = 'London';
    // ACT
    try {
       await config.flightSuretyApp.purchaseInsurance(config.firstAirline, flightNumber, timestamp,
       {from: accounts[7], value: payment, gasPrice: 0});
    }
    catch(e) {
        reverted = true;
    }
    // ASSERT
    assert.equal(reverted, true, "Error: Payment should not have been accepted.");
  });

  it('(payment) can purchase flight insurance within the limit', async () => {
    // ARRANGE
    const payment = Web3.utils.toWei('1', "ether");
    const timestamp = Math.floor(Date.now() / 1000);
    const flightNumber = 'London';
    // ACT
    try {
       await config.flightSuretyApp.purchaseInsurance(config.firstAirline, flightNumber, timestamp,
       {from: accounts[7], value: payment, gasPrice: 0});
    }
    catch(e) {
        reverted = true;
    }
    // ASSERT
    const purchased = await config.flightSuretyData.isInsurancePurchased(config.firstAirline, flightNumber, timestamp);
    assert.equal(purchased, true, "Error: Payment should not have been accepted.");
  });
});