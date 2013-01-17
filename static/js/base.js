// @require 'js/jquery.js'

S = {};

// Precached DOM elements
S.DOM = {};
S.DOM.win = $(window);
S.DOM.doc = $(document);
S.DOM.html = $('html');
S.DOM.header = $('#l-header');
S.DOM.footer = $('#l-footer');
S.DOM.content = $('#l-content');

// All module objects stored here
S.modules = {};

// Setting up environment for CSS
S.DOM.html.removeClass('no-js').addClass('js');

S.browser.isOpera   && S.DOM.html.addClass('opera');
S.browser.isFirefox && S.DOM.html.addClass('firefox');
S.browser.isIE      && S.DOM.html.addClass('ie ie' + S.browser.isIE);
S.browser.isIOS     && S.DOM.html.addClass('ios ios' + S.browser.isIOS);
S.browser.isAndroid && S.DOM.html.addClass('android android' + S.browser.isAndroid);
