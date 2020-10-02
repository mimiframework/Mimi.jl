import React from 'react';
import './App.css';
import ExplorerTreeView from './ExplorerTreeView'
import ExplorerDataView from './ExplorerDataView'

function App() {    
  return (
    <div className="App">
      <div className="ExplorerBar">
          <ExplorerTreeView
            name="Components"
          ></ExplorerTreeView>
          <ExplorerDataView
            id="datalist"
            name="Data"
          ></ExplorerDataView>
      </div>
      <div id="vis" className="graphic"></div>
    </div>
  );
}

export default App;
