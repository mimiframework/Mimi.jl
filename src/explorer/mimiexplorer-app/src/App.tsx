import React from 'react';
import './App.css';
import ExplorerTreeView from './ExplorerTreeView'

function App() {    
  return (
    <div className="App">
      <ExplorerTreeView
        id="variablelist"
        name="Values"
      ></ExplorerTreeView>
      <div id="vis" className="graphic"></div>
    </div>
  );
}

export default App;
