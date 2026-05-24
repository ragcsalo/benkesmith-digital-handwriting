package com.benkesmith.digitalhandwriting;

import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.CallbackContext;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import com.google.mlkit.vision.digitalink.recognition.Ink;
import com.google.mlkit.vision.digitalink.recognition.Ink.Stroke;
import com.google.mlkit.vision.digitalink.recognition.DigitalInkRecognition;
import com.google.mlkit.vision.digitalink.recognition.DigitalInkRecognizer;
import com.google.mlkit.vision.digitalink.recognition.DigitalInkRecognizerOptions;
import com.google.mlkit.vision.digitalink.recognition.DigitalInkRecognitionModel;
import com.google.mlkit.vision.digitalink.recognition.DigitalInkRecognitionModelIdentifier;

import com.google.mlkit.common.model.RemoteModelManager;

public class DigitalHandWriting extends CordovaPlugin {

    @Override
    public boolean execute(String action, JSONArray args, CallbackContext callbackContext) throws JSONException {
        if (action.equals("recognize")) {
            JSONObject inkData = args.getJSONObject(0);
            String langTag = args.getString(1);

            // Execute on the thread pool to avoid blocking the WebCore / UI thread
            cordova.getThreadPool().execute(new Runnable() {
                @Override
                public void run() {
                    processInk(inkData, langTag, callbackContext);
                }
            });
            return true;
        }
        return false;
    }

    private void processInk(JSONObject inkData, String langTag, CallbackContext callbackContext) {
        try {
            Ink.Builder inkBuilder = Ink.builder();
            JSONArray strokesArray = inkData.getJSONArray("strokes");

            // Parse JS canvas tracking coordinates into native ML Kit objects
            for (int i = 0; i < strokesArray.length(); i++) {
                Stroke.Builder strokeBuilder = Stroke.builder();
                JSONArray pointsArray = strokesArray.getJSONObject(i).getJSONArray("points");

                for (int j = 0; j < pointsArray.length(); j++) {
                    JSONObject p = pointsArray.getJSONObject(j);
                    float x = (float) p.getDouble("x");
                    float y = (float) p.getDouble("y");
                    long t = p.getLong("t");
                    strokeBuilder.addPoint(Ink.Point.create(x, y, t));
                }
                inkBuilder.addStroke(strokeBuilder.build());
            }

            Ink ink = inkBuilder.build();

            // Match language string (e.g., "en", "hu") to ML Kit model space
            DigitalInkRecognitionModelIdentifier modelIdentifier =
                    DigitalInkRecognitionModelIdentifier.fromLanguageTag(langTag);

            if (modelIdentifier == null) {
                callbackContext.error("Unsupported language tag: " + langTag);
                return;
            }

            DigitalInkRecognitionModel model =
                    DigitalInkRecognitionModel.builder(modelIdentifier).build();
            RemoteModelManager modelManager = RemoteModelManager.getInstance();

            // Auto-download checking logic runs off-ui thread safely here
            modelManager.isModelDownloaded(model).addOnSuccessListener(isDownloaded -> {
                if (isDownloaded) {
                    performRecognition(model, ink, callbackContext);
                } else {
                    // Downloads language pack dynamically if missing (~20MB)
                    modelManager.download(model, new com.google.mlkit.common.model.DownloadConditions.Builder().build())
                            .addOnSuccessListener(aVoid -> performRecognition(model, ink, callbackContext))
                            .addOnFailureListener(e -> callbackContext.error("Model download failed: " + e.getMessage()));
                }
            });

        } catch (Exception e) {
            callbackContext.error("Data processing exception: " + e.getMessage());
        }
    }

    private void performRecognition(DigitalInkRecognitionModel model, Ink ink, CallbackContext callbackContext) {
        DigitalInkRecognizer recognizer = DigitalInkRecognition.getClient(
                DigitalInkRecognizerOptions.builder(model).build()
        );

        recognizer.recognize(ink)
                .addOnSuccessListener(result -> {
                    try {
                        JSONObject response = new JSONObject();
                        if (!result.getCandidates().isEmpty()) {
                            // Return the highest-confidence prediction candidate
                            response.put("text", result.getCandidates().get(0).getText());
                        } else {
                            response.put("text", "");
                        }
                        callbackContext.success(response);
                    } catch (JSONException e) {
                        callbackContext.error("JSON formatting error: " + e.getMessage());
                    }
                })
                .addOnFailureListener(e -> callbackContext.error("Recognition failed: " + e.getMessage()));
    }
}
