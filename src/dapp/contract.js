import FlightSuretyApp from '../../build/contracts/FlightSuretyApp.json';
import FlightSuretyData from '../../build/contracts/FlightSuretyData.json';
import Config from './config.json';
import Web3 from 'web3';

export default class Contract {
    constructor(network, callback) {

        let config = Config[network];
        this.web3 = new Web3(new Web3.providers.HttpProvider(config.url));
        this.flightSuretyData = new this.web3.eth.Contract(FlightSuretyData.abi, config.dataAddress);
        this.flightSuretyApp = new this.web3.eth.Contract(FlightSuretyApp.abi, config.appAddress);
        this.initialize(callback);
        this.owner = null;
        this.airlines = [];
        this.passengers = [];
    }

    initialize(callback) {
        let self = this;

        this.web3.eth.getAccounts( (error, accts) => {
            
            try {
                self.owner = accts[0];
                console.log('Owner: ', self.owner);

                let counter = 1;
                
                while(this.airlines.length < 5) {
                    this.airlines.push(accts[counter++]);
                }
                console.log('Airlines: ', JSON.stringify(self.airlines));

                while(this.passengers.length < 5) {
                    this.passengers.push(accts[counter++]);
                }
                console.log('Passengers: ', JSON.stringify(self.passengers));

                callback();
            } catch (e) {
                console.log(e);
            }
        });
    }


    isOperational(callback) {
       let self = this;
       self.flightSuretyApp.methods
            .isOperational()
            .call({ from: self.owner}, callback);
    }

    fetchFlightStatus(flight, callback) {
        let self = this;
        let payload = {
            airline: self.airlines[0],
            flight: flight,
            timestamp: Math.floor(Date.now() / 1000)
        } 
        self.flightSuretyApp.methods
            .fetchFlightStatus(payload.airline, payload.flight, payload.timestamp)
            .send({ from: self.owner}, (error, result) => {
                callback(error, payload);
            });
    }

    fundAirline(callback) {
        let self = this;
        self.flightSuretyApp.methods
            .fundAirline()
            .send({from: self.airlines[0], value: this.web3.utils.toWei("10", "ether")}, callback)
    }

    registerFlight(flight, timestamp, callback) {
        let self = this;
        let payload = {
            airline: self.airlines[0],
            flight: flight,
            timestamp: timestamp
        }
        self.flightSuretyApp.methods
            .registerFlight(payload.airline, payload.flight, payload.timestamp)
            .send({from: self.owner, gas: 6721970}, (error, result) => {
                callback(error, result);
            }); 
    }

    purchaseInsurance(flight, timestamp, insurancevalue, callback) {
        let self = this;
        let payload = {
            airline: self.airlines[0],
            flight: flight,
            timestamp: timestamp
        }
        let amount = this.web3.utils.toWei(insuranceValue.toString(), "ether");
        self.flightSuretyApp.methods
            .purchaseInsurance(payload.airline, payload.flight, payload.timestamp)
            .send({from: self.owner, value: amount, gas: 6721970}, (error, result) => {
                callback(error, result)
            })
    }
}