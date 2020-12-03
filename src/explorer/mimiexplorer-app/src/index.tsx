import embed from 'vega-embed';
import React from 'react';
import ReactDOM from 'react-dom';
import App from './App';
import * as serviceWorker from './serviceWorker';
import { withStyles } from "@material-ui/core/styles";

// https://codesandbox.io/s/l48vjmk3om

const styles = theme => ({
  "@global": {
    // MUI typography elements use REMs, so you can scale the global
    // font size by setting the font-size on the <html> element.
    html: {
      fontSize: 12
    }
  }
});

const AppStyled = withStyles(styles)(App)

ReactDOM.render(
  <AppStyled />,
  document.getElementById('root')
);

// If you want your app to work offline and load faster, you can change
// unregister() to register() below. Note this comes with some pitfalls.
// Learn more about service workers: https://bit.ly/CRA-PWA

serviceWorker.unregister();

function display(spec) {
  embed("#vis", spec["VLspec"], {actions: false});
}

global['display'] = display
