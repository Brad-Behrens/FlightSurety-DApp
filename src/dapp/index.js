import DOM from './dom';
import Contract from './contract';
import './flightsurety.css';


(async() => {

    let result = null;

    const FLIGHTS = [
        {
            name: 'London',
            timestamp: Math.floor(Date.now() / 1000)
        },
        {
            name: 'Paris',
            timestamp: Math.floor(Date.now() / 1000)
        },
        {
            name: 'Singapore',
            timestamp: Math.floor(Date.now() / 1000)
        }
    ];

    let contract = new Contract('localhost', () => {

        // Read transaction
        contract.isOperational((error, result) => {
            console.log(error,result);
            display('Operational Status', 'Check if contract is operational', [ { label: 'Operational Status', error: error, value: result} ]);
        });
    

        // User-submitted transaction
        DOM.elid('submit-oracle').addEventListener('click', () => {
            let flight = DOM.elid('dropdown_flight').value;
            // Write transaction
            contract.fetchFlightStatus(flight, (error, result) => {
                display('Oracles', 'Trigger oracles', [ { label: 'Fetch Flight Status', error: error, value: result.flight + ' ' + result.timestamp} ]);
            });
        })

        // User-submitted transaction
        DOM.elid('fundAirline').addEventListener('click', () => {
            contract.fundAirline((error, result) => {
                console.log(result);
            });
        })

        // User-submitted transaction
        DOM.elid('registerFlight').addEventListener('click', () => {
            let flight = DOM.elid('registerFlights_dropdown').value;

            let timestamp = () => {
                for(let i = 0; i < FLIGHTS.length; i++) {
                    if(FLIGHTS[i].name === flight) {
                        timestamp = FLIGHTS[i].timestamp;
                    }
                }
            }

            contract.registerFlight(flight, timestamp, (error, result) => {
                if(error) {
                    console.log(error);
                }
                console.log(result);
            });
        })   
        
        DOM.elid('purchase-insurance').addEventListener('click', () => {
            let flight = DOM.elid('dropdown_flight').value;

            let timestamp = () => {
                for(let i = 0; i < FLIGHTS.length; i++) {
                    if(FLIGHTS[i].name === flight) {
                        timestamp = FLIGHTS[i].timestamp;
                    }
                }
            }

            let insuranceValue = DOM.elid('insuranceValue').value;

            contract.purchaseInsurance(flight, timestamp, insuranceValue, (error, result) => {
                if(error) {
                    console.log(error);
                }
                console.log(result);
            })
        })


    });
})();


function display(title, description, results) {
    let displayDiv = DOM.elid("display-wrapper");
    let section = DOM.section();
    section.appendChild(DOM.h2(title));
    section.appendChild(DOM.h5(description));
    results.map((result) => {
        let row = section.appendChild(DOM.div({className:'row'}));
        row.appendChild(DOM.div({className: 'col-sm-4 field'}, result.label));
        row.appendChild(DOM.div({className: 'col-sm-8 field-value'}, result.error ? String(result.error) : String(result.value)));
        section.appendChild(row);
    })
    displayDiv.append(section);

}



