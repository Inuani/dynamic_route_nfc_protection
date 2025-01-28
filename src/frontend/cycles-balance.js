import { actor } from './actor.js';
import elements from './elements.js';

function formatCycles(cycles) {
    if (cycles >= 1_000_000_000_000) {
        return (cycles / 1_000_000_000_000).toFixed(2) + ' T';
    } else if (cycles >= 1_000_000_000) {
        return (cycles / 1_000_000_000).toFixed(2) + ' B';
    } else if (cycles >= 1_000_000) {
        return (cycles / 1_000_000).toFixed(2) + ' M';
    } else if (cycles >= 1_000) {
        return (cycles / 1_000).toFixed(2) + ' K';
    }
    return cycles.toString();
}

const MAX_CYCLES = 5_000_000_000_000;

async function updateBalance() {
    try {
        const balance = Number(await actor.get_cycle_balance());
        const percentage = Math.min((balance / MAX_CYCLES) * 100, 100);
        
        const energyFill = elements.energy.fill();
        const energyText = elements.energy.text();
        const rawBalance = elements.energy.balance();
        const percentageElement = elements.energy.percentage();

            energyFill.style.width = `${percentage}%`;
            
            if (percentage < 20) {
                energyFill.style.background = 'linear-gradient(90deg, #ff5252, #ff8a80)';
            } else if (percentage < 50) {
                energyFill.style.background = 'linear-gradient(90deg, #ffd740, #ffecb3)';
            } else {
                energyFill.style.background = 'linear-gradient(90deg, #4CAF50, #8BC34A)';
            }
      
            energyText.innerText = `${formatCycles(balance)} cycles`;
            rawBalance.innerText = `Total: ${formatCycles(balance)} cycles`;
            percentageElement.innerText = `${percentage.toFixed(1)}% of max capacity`;
       
    } catch (error) {
        console.error('Error fetching balance:', error);
    }
}

export { updateBalance };

function openRefuelWindow() {

    const width = 400;
    const height = 700;
    const left = window.screen.width / 2 - width / 2;
    const top = window.screen.height / 2 - height / 2;

    const windowFeatures = `
        width=${width},
        height=${height},
        left=${left},
        top=${top},
        toolbar=0,
        location=0,
        menubar=0,
        status=0
    `.replace(/\s/g, '');

    const refuelUrl = `https://cycle.express/?to=${process.env.CANISTER_ID_DYNA_NFC_PROTECT_ROUTES}`;
    window.open(refuelUrl, 'Refuel Window', windowFeatures);
}

document.getElementById('refuel-button')?.addEventListener('click', openRefuelWindow);

export { openRefuelWindow };