const elements = {
    auth: {
      button: () => document.getElementById('auth-button'),
      principalDisplay: () => document.getElementById('principal-display')
    },
    
    energy: {
      fill: () => document.getElementById('energy-fill'),
      text: () => document.getElementById('energy-text'),
      balance: () => document.getElementById('raw-balance'),
      percentage: () => document.getElementById('percentage')
    },
  
    ownership: {
      removeController: () => document.getElementById('remove-controller'),
      checkController: () => document.getElementById('check-controller'),
      controllerStatus: () => document.getElementById('controller-status'),
      getOwnership: () => document.getElementById('get-ownership')
    }
  };
  
  export default elements;