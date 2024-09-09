/**
 * @author: Grant Kellie (grantkellie.dev)
 * @description: hides or shows elements that require or don't require javascript enabled in the users browser.
 */

document.addEventListener("DOMContentLoaded", function() {
    // Show elements meant for JS-enabled browsers
    var jsEnabledElements = document.querySelectorAll('.js-enabled');
    jsEnabledElements.forEach(function(element) {
        element.style.display = 'unset';
    });

    // Hide elements meant for JS-disabled browsers
    var jsDisabledElements = document.querySelectorAll('.js-disabled');
    jsDisabledElements.forEach(function(element) {
        element.style.display = 'none';
    });
});