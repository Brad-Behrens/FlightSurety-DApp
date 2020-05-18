import FlightSuretyApp from '../../build/contracts/FlightSuretyApp.json';
import FlightSuretyData from '../../build/contracts/FlightSuretyData.json';
import Config from './config.json';
import Web3 from 'web3';
import express from 'express';


let config = Config['localhost'];
let web3 = new Web3(new Web3.providers.WebsocketProvider(config.url.replace('http', 'ws')));
web3.eth.defaultAccount = web3.eth.accounts[0];
let flightSuretyApp = new web3.eth.Contract(FlightSuretyApp.abi, config.appAddress);
let flightSuretyData = new web3.eth.Contract(FlightSuretyData.abi, config.dataAddress);

// Oracles
let ORACLE_OFFSET = 20;
let ORACLE_COUNT = 40;
let Oracles = [];

// Status Codes
const STATUS_CODE_UNKNOWN = 0;
const STATUS_CODE_ON_TIME = 10;
const STATUS_CODE_LATE_AIRLINE = 20;
const STATUS_CODE_LATE_WEATHER = 30;
const STATUS_CODE_LATE_TECHNICAL = 40;
const STATUS_CODE_LATE_OTHER = 50;
const STATUS_CODES = [STATUS_CODE_UNKNOWN, STATUS_CODE_ON_TIME, STATUS_CODE_LATE_AIRLINE, STATUS_CODE_LATE_WEATHER, STATUS_CODE_LATE_TECHNICAL, STATUS_CODE_LATE_OTHER];

// Register Oracles
web3.eth.getAccounts((error, accounts) => {
    // Loop through oracle count
    for(let i = ORACLE_OFFSET; i < ORACLE_COUNT; i++) {
        // Register Oracle
        flightSuretyApp.methods.registerOracle()
        .send({from: accounts[i], value: web3.utils.toWei("1", "ether"), gas: 9999999}, (error, result) => {
            flightSuretyApp.methods.getMyIndexes().call({from: accounts[i]}, (error, result) => {
                let oracle = {
                    address: accounts[i],
                    index: result
                };
                Oracles.push(oracle);
                console.log("Oracle Registered at: ", oracle.address);
            });
        });
    }
});

// Oracle Functionality
flightSuretyApp.events.OracleRequest({
    fromBlock: 0
  }, function (error, event) {
    if (error) {
        console.log(error)
    }

    let randomStatusCode = STATUS_CODES[Math.floor(Math.random() * STATUS_CODES.length)]
    let eventValue = event.returnValues;
    let reqIndex = eventValue.index;
    let airline = eventValue.airline;
    let flight = eventValue.flight;
    let timestamp = eventValue.timestamp;

    console.log('Event: ', eventValue);

    // Loop through Oracles array and determine correct index value.
    Oracles.forEach((oracle) => {
        if(oracle.index == reqIndex) {
            // Oracle Response
            flightSuretyApp.methods.submitOracleResponse(reqIndex, airline, flight, timestamp,randomStatusCode)
            .send({from: oracle.address, gas: 9999999}, (error, result) => {
                console.log('Oracle Response from: ' + oracle.address + ' Status Code: ' + randomStatusCode );
            });
        }
    });
});


const app = express();
app.get('/api', (req, res) => {
    res.send({
      message: 'An API for use with your Dapp!'
    })
})

export default app;