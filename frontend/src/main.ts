import { OpenProjectModule } from 'core-app/app.module';
import { enableProdMode } from '@angular/core';
import * as jQuery from 'jquery';
import { platformBrowserDynamic } from '@angular/platform-browser-dynamic';
import { initializeLocale } from 'core-app/core/setup/init-locale';
import { environment } from './environments/environment';
import { configureErrorReporter } from 'core-app/core/errors/configure-reporter';
import { initializeGlobalListeners } from 'core-app/core/setup/globals/global-listeners';

(window as any).global = window;

// Ensure we set the correct dynamic frontend path
// based on the RAILS_RELATIVE_URL_ROOT setting
// https://webpack.js.org/guides/public-path/
const ASSET_BASE_PATH = '/assets/frontend/';

// Sets the relative base path
window.appBasePath = jQuery('meta[name=app_base_path]').attr('content') || '';

// Get the asset host, if any
const initializer = document.querySelector<HTMLMetaElement>('meta[name="openproject_initializer"]');
const ASSET_HOST = initializer?.dataset.assetHost ? `//${initializer.dataset.assetHost}` : '';

// Ensure to set the asset base for dynamic code loading
// https://webpack.js.org/guides/public-path/
__webpack_public_path__ = ASSET_HOST + window.appBasePath + ASSET_BASE_PATH;

window.ErrorReporter = configureErrorReporter();

require('core-app/core/setup/init-vendors');
require('core-app/core/setup/init-globals');
require('stimulus/setup');
require('turbo/setup');

if (environment.production) {
  enableProdMode();
}

// Function to set target="_self" on all <a> elements
function setLinkTargets() {
  const links = document.querySelectorAll('a');
  links.forEach(link => {
    link.setAttribute('target', '_self');
  });
}

// Use MutationObserver to monitor changes to the DOM
function observeDOMChanges() {
  const observer = new MutationObserver((mutations) => {
    mutations.forEach((mutation) => {
      if (mutation.type === 'childList') {
        mutation.addedNodes.forEach((node) => {
          if (node.nodeType === Node.ELEMENT_NODE) {
            const element = node as HTMLElement;
            if (element.tagName === 'A') {
              element.setAttribute('target', '_self');
            } else {
              const links = element.querySelectorAll('a');
              links.forEach(link => {
                link.setAttribute('target', '_self');
              });
            }
          }
        });
      }
    });
  });

  observer.observe(document.body, {
    childList: true,
    subtree: true
  });
}

// Import the correct locale early on
void initializeLocale()
  .then(() => {
    jQuery(() => {
      // Now that DOM is loaded, also run the global listeners
      initializeGlobalListeners();

      // Set target="_self" for existing links
      setLinkTargets();

      // Observe DOM changes to set target="_self" for new links
      observeDOMChanges();

      // Due to the behaviour of the Edge browser we need to wait for 'DOM ready'
      void platformBrowserDynamic()
        .bootstrapModule(OpenProjectModule)
        .then(() => {
          jQuery('body').addClass('__ng2-bootstrap-has-run');
        });
    });
  });
