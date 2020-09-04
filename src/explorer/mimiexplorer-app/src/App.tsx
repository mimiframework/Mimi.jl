import React from 'react';
import './App.css';
import ExplorerTreeView from './ExplorerTreeView'
import ExplorerVariableView from './ExplorerVariableView'

function App() {    
  return (
    <div className="App">
      <ExplorerTreeView
        name="Subcomponents"
      ></ExplorerTreeView>
      <br/>
      <hr/>
      <br/>
      <ExplorerVariableView
        id="variablelist"
        name="Values"
      ></ExplorerVariableView>
      <div id="vis" className="graphic"></div>
    </div>
  );
}

export default App;
