/**
 * @title Debug Overflow
 * @desc: a JavaScript utility that displays and logs container overflow of elements.
 * @author: Grant Kellie (grantkellie.dev)
 */

function isOverflowing(element) {
    return element.scrollWidth > element.clientWidth || element.scrollHeight > element.clientHeight;
}

function highlightElement(element, isChild) {
    // element.style.border = isChild ? '2px solid purple' : ''; // Highlight colors
    element.style.backgroundColor = isChild ? 'rgba(128, 0, 128, 0.2)' : ''; // Transparent colors
    element.style.overflow = isChild ? 'hidden' : ''; // Transparent colors
}

function logOverflowingElements(element, level = 0) {
    const isOverflowingElement = isOverflowing(element);

    if (isOverflowingElement) {
        const indent = ' '.repeat(level * 2);
        highlightElement(element, level > 0); // Highlight child elements differently

        console.group(`${indent}${level > 0 ? 'Overflowing Child' : 'Overflowing Container'}`);
        console.log('Element:', element);

        // Process child elements
        Array.from(element.children).forEach(child => logOverflowingElements(child, level + 1));

        console.groupEnd();
    } else if (level > 0) { // If it's a child and not overflowing
        highlightElement(element, true); // Highlight child elements even if they are not overflowing
        console.group(`  ${' '.repeat(level * 2)}Non-overflowing Child`);
        console.log('Element:', element);
        console.groupEnd();
    }
}

// Execute the overflow detection and logging
const containers = document.querySelectorAll('.container');
containers.forEach(container => logOverflowingElements(container));
