var exec = require('cordova/exec');

module.exports = {
    recognize: function (inkData, languageTag, successCallback, errorCallback) {
        exec(
            successCallback, 
            errorCallback, 
            'DigitalHandWriting', // Native Class Service name
            'recognize',          // Action string
            [inkData, languageTag] // Array of arguments passed to Java
        );
    }
};
