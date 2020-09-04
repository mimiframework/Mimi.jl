import React from 'react';
import './App.css';
import ExplorerTreeView from './ExplorerTreeView'
import ExplorerDataView from './ExplorerDataView'

function App() {    
  return (
    <div className="App">
      <ExplorerTreeView
        name="Components"
      ></ExplorerTreeView>
      <br/>
      <hr/>
      <br/>
      <ExplorerDataView
        id="datalist"
        name="Data"
      ></ExplorerDataView>
      <div id="vis" className="graphic"></div>
    </div>
  );
}

export default App;
