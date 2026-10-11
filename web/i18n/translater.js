const i18n = {};
const languageDefault = 'en';
const defaultEngText = {
  title: 'Download NumberInbox application',
  description: 'Email, reimagined with your number.',
  open: 'Open'
};

/**
 * @description Check if the language is valid
 * @param {String} language 
 * @returns {boolean}
 */
function isValidUserLanguage(language) {
  if (language == null || language == undefined) {
    return false;
  }
  return true;
}

/**
 * @description Get the user language
 * @returns {String}
 */
function getUserLanguage() {
  let userLanguage = languageDefault;

  try {
    const language = navigator.language;
    if (isValidUserLanguage(language)) {
      userLanguage = language.split('-')[0];
    }
  } catch (error) {
    console.error(`[NumberInbox] Error getting user language:`, error);
  }

  console.info(`[NumberInbox] Current Language: `, userLanguage);
  return userLanguage;
}

/**
 * @description Load the language resources
 * @returns {Promise<void>}
 */
async function loadLanguageResources() {
  const language = getUserLanguage();
  try {
    const response = await fetch(`/i18n/${language}.json`);
    const data = await response.json();
    i18n[language] = data;
    console.info(`[NumberInbox] Successfully loaded ${language} resources:`, i18n[language]);
  } catch (error) {
    console.error(`[NumberInbox] Error loading ${language} resources:`, error);
    i18n['en'] = defaultEngText;
    console.info(`[NumberInbox] Using default English resources:`, i18n['en']);
  }
}

/**
 * @description Set the text content of smart banner
 * @typedef SetTextContentParams
 * @property {String} id
 * @property {String} text 
 * @param {SetTextContentParams} param
 * @returns {void}
 */
function setTextContent({id, text}) {
  document.getElementById(id).textContent = text;
}

/**
 * @description Apply the loaded resources to the smart banner text
 * @returns {void}
 */
function applyLanguageResources() {
  const language = getUserLanguage();

  let languageResources = defaultEngText;

  if (i18n[language] !== null && i18n[language] !== undefined) {
    languageResources = i18n[language];
  }

  setTextContent({
    id: 'banner-title-id',
    text: languageResources.title
  });
  setTextContent({
    id: 'banner-description-id',
    text: languageResources.description
  });
  setTextContent({
    id: 'open-button-id',
    text: languageResources.open
  });
}

/**
 * @description Load the banner translations once, apply them, then continue
 * startup. `initialTmailApp` can render the banner, so the text has to be in
 * place before the app starts; fetching here again would duplicate the request
 * `web/index.html` already performs.
 * @param {Function} onReady
 * @returns {Promise<void>}
 */
function initializeLocalizedApp(onReady) {
  return loadLanguageResources()
    .then(applyLanguageResources)
    .finally(onReady);
}
