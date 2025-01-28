import { AuthClient } from "@dfinity/auth-client";
import { actor, updateActorIdentity } from './actor.js';
import elements from './elements.js';

export class Auth {
  constructor() {
    this.currentActor = actor;
    this.authClient = null;
    
    this.identityProvider = process.env.DFX_NETWORK === "ic" 
      ? "https://identity.ic0.app"
      : `http://${process.env.CANISTER_ID_INTERNET_IDENTITY}.localhost:4943`;
  }

  get principalElement() {
    return elements.auth.principalDisplay(); 
  }

  get authButton() {
    return elements.auth.button(); 
  }
  // UI Updates
  async updatePrincipalDisplay() {
    if (!this.principalElement) return;

    try {
      const principal = await this.currentActor.whoAmI();
      this.principalElement.textContent = principal.toText();
    } catch (error) {
      console.error("Error getting principal:", error);
      this.principalElement.textContent = "Error fetching principal";
      throw new Error("Failed to fetch principal");
    }
  }

  updateAuthButtonState(isAuthenticated) {
    if (!this.authButton) return;
    this.authButton.textContent = isAuthenticated 
      ? 'Sign Out' 
      : '✨ Sign in for Magic ✨';
  }

  // Authentication Handlers
  async handleAuthenticated(authClient) {
    try {
      const identity = authClient.getIdentity();
      this.currentActor = updateActorIdentity(identity);
      await this.updatePrincipalDisplay();
      this.updateAuthButtonState(true);
    } catch (error) {
      console.error("Authentication handling failed:", error);
      this.handleAuthError(error);
    }
  }

  async handleSignOut() {
    try {
      await this.authClient.logout();
      this.currentActor = actor;
      await this.updatePrincipalDisplay();
      this.updateAuthButtonState(false);
    } catch (error) {
      console.error("Sign out failed:", error);
      this.handleAuthError(error);
    }
  }

  async handleSignIn() {
    if (!this.authClient) {
      throw new Error("Auth client not initialized");
    }

    try {
      await new Promise((resolve, reject) => {
        this.authClient.login({
          identityProvider: this.identityProvider,
          onSuccess: resolve,
          onError: reject,
          windowOpenerFeatures: this.getLoginWindowFeatures()
        });
      });

      if (await this.authClient.isAuthenticated()) {
        await this.handleAuthenticated(this.authClient);
      }
    } catch (error) {
      if (error?.message === "UserInterrupt") {
        console.log("Login cancelled by user");
        return;
      }
      this.handleAuthError(error);
    }
  }

  handleAuthError(error) {
    console.error("Authentication error:", error);
    this.updateAuthButtonState(false);
  
  }

  // Event Handlers
  setupAuthButton() {
    this.authButton?.addEventListener('click', async () => {
      if (!this.authClient) return;

      try {
        const isAuthenticated = await this.authClient.isAuthenticated();
        if (isAuthenticated) {
          await this.handleSignOut();
        } else {
          await this.handleSignIn();
        }
      } catch (error) {
        this.handleAuthError(error);
      }
    });
  }

  // Initialization
  async init() {
    try {
        this.authClient = await AuthClient.create();
        const isAuthenticated = await this.authClient.isAuthenticated();
        const identity = this.authClient.getIdentity();
        this.currentActor = updateActorIdentity(identity);

        await this.updatePrincipalDisplay();
        this.updateAuthButtonState(isAuthenticated);
        this.setupAuthButton();
    } catch (error) {
        console.error("Initialization failed:", error);
        this.handleAuthError(error);
    }
}

  // Utility Methods
  getLoginWindowFeatures() {
    const width = 400;
    const height = 500;
    const left = window.screen.width / 2 - width / 2;
    const top = window.screen.height / 2 - height / 2;

    return `
      width=${width},
      height=${height},
      left=${left},
      top=${top},
      toolbar=0,
      location=0,
      menubar=0,
      status=0
    `.replace(/\s/g, '');
  }

  getCurrentActor() {
    return this.currentActor;
  }
}