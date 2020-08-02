import * as electron from 'electron';
import embed from 'vega-embed';
import React from 'react';
import ReactDOM from 'react-dom';
import './index.css';
import App from './App';
import * as serviceWorker from './serviceWorker';

ReactDOM.render(
  <React.StrictMode>
    <App />
  </React.StrictMode>,
  document.getElementById('root')
);

// If you want your app to work offline and load faster, you can change
// unregister() to register() below. Note this comes with some pitfalls.
// Learn more about service workers: https://bit.ly/CRA-PWA
serviceWorker.unregister();

function refreshItemsList(menu_item_list: any) {

  var element = document.getElementById("variablelist");
  
  for (var i in menu_item_list) {
      var newButton = document.createElement("button");
      newButton.setAttribute("class", "tab");
      
      // Set onclick for button
      newButton.onclick = (function() {
          var comp_name = menu_item_list[i]["comp_name"]
          var item_name = menu_item_list[i]["item_name"]
          return function() {
            global['sendMessageToJulia']({cmd: 'display_spec', comp_name: comp_name, item_name: item_name})
          }
      })()
      newButton.appendChild(document.createTextNode(menu_item_list[i]["name"]));
      element!.appendChild(newButton);
  }
}

function display(spec) {
  embed("#vis", spec["VLspec"], {actions: false});
}

global['refreshItemsList'] = refreshItemsList
global['display'] = display
