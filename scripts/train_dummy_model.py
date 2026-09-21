import os
import json
import numpy as np
import tensorflow as tf

def train_and_export_dummy_model(kit_id, num_classes=10, img_size=(224, 224)):
    print(f"Generating dummy data for {kit_id}...")
    
    # Generate dummy data (e.g. 100 images per class)
    X_train = np.random.rand(100 * num_classes, img_size[0], img_size[1], 3).astype(np.float32)
    y_train = np.random.randint(0, num_classes, 100 * num_classes)
    
    y_train_one_hot = tf.keras.utils.to_categorical(y_train, num_classes)

    print("Building a simple CNN model...")
    model = tf.keras.Sequential([
        tf.keras.layers.InputLayer(input_shape=(img_size[0], img_size[1], 3)),
        tf.keras.layers.Conv2D(16, (3,3), activation='relu'),
        tf.keras.layers.MaxPooling2D(2,2),
        tf.keras.layers.Flatten(),
        tf.keras.layers.Dense(32, activation='relu'),
        tf.keras.layers.Dense(num_classes, activation='softmax')
    ])
    
    model.compile(optimizer='adam', loss='categorical_crossentropy', metrics=['accuracy'])
    
    print("Training model (1 epoch just for structure)...")
    model.fit(X_train, y_train_one_hot, epochs=1, batch_size=32)

    # Convert to TFLite
    print("Converting to TFLite...")
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    tflite_model = converter.convert()

    # Save outputs
    output_dir = os.path.join(os.path.dirname(__file__), '..', 'assets', 'models')
    os.makedirs(output_dir, exist_ok=True)
    
    tflite_path = os.path.join(output_dir, f"{kit_id}.tflite")
    with open(tflite_path, "wb") as f:
        f.write(tflite_model)
    print(f"Saved TFLite model to {tflite_path}")

    # Generate labels JSON
    labels_data = {
        "kitId": kit_id,
        "classes": [
            {"index": 0, "substance": "Cocaine"},
            {"index": 1, "substance": "MDMA"},
            {"index": 2, "substance": "Methamphetamine"},
            {"index": 3, "substance": "Heroin"},
            {"index": 4, "substance": "Fentanyl"},
            {"index": 5, "substance": "LSD"},
            {"index": 6, "substance": "Ketamine"},
            {"index": 7, "substance": "Psilocybin"},
            {"index": 8, "substance": "Amphetamine"},
            {"index": 9, "substance": "Oxycodone"}
        ]
    }
    
    labels_path = os.path.join(output_dir, f"{kit_id}_labels.json")
    with open(labels_path, "w") as f:
        json.dump(labels_data, f, indent=2)
    print(f"Saved labels to {labels_path}")
    
    print("Done!")

if __name__ == "__main__":
    train_and_export_dummy_model("kit_v1")
