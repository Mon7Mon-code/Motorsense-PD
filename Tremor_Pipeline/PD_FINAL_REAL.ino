// =============================================================================
// PD_Monitor_v3.ino
//
// BLE UUIDs
// ---------
//  Service        : A1B2C3D4-E5F6-7890-ABCD-EF1234567890
//  Characteristic : B2C3D4E5-F6A7-8901-BCDE-F12345678901
//
// BLE format (one line per sample, 10 samples per notify):
//   ax_rms,log_power,dom_freq,p_tremor,severity,accX,accY,accZ,gyrX,gyrY,gyrZ
//   e.g. 0.1234,-1.2345,5,0.8732,MODERATE,9.8100,0.1234,-0.2345,0.0012,0.0034,-0.0056
//
// Tremor values update every 1s (50 samples), repeat on each line until next window.
// =============================================================================

#include <LSM6DS3.h>
#include <Wire.h>
#include <bluefruit.h>
#include "model_weights.h"

// ------------------------------------------------------------
// Struct definitions
// ------------------------------------------------------------
struct TremorFeatures {
    float log_power;   // log10 of 4-6 Hz band power
    float rms;         // RMS of gravity-subtracted magnitude
    float dom_freq;    // dominant bin → Hz
};

// ------------------------------------------------------------
// IMU
// ------------------------------------------------------------
LSM6DS3 myIMU(I2C_MODE, 0x6A);

// ------------------------------------------------------------
// Sampling — 50 Hz
// ------------------------------------------------------------
const int   SAMPLE_RATE_HZ     = 50;
const int   SAMPLE_INTERVAL_MS = 1000 / SAMPLE_RATE_HZ;  // 20 ms
const int   WINDOW_SIZE        = 50;

unsigned long lastSampleTime = 0;

// ------------------------------------------------------------
// Tremor buffer
// ------------------------------------------------------------
float buf_x[WINDOW_SIZE];
float buf_y[WINDOW_SIZE];
float buf_z[WINDOW_SIZE];

int  buf_index = 0;
bool buf_full  = false;

// ------------------------------------------------------------
// Latest tremor results (updated every 1s, repeated each line)
// ------------------------------------------------------------
float latest_rms       = 0.0f;
float latest_log_power = 0.0f;
int   latest_dom_freq  = 0;
float latest_p_tremor  = 0.0f;
const char* latest_severity = "NONE";

// ------------------------------------------------------------
// BLE batch buffer
// ------------------------------------------------------------
const int BLE_BATCH_SIZE = 6;
char      bleBatch[BLE_BATCH_SIZE * 80];  // wider for full line
int       batchCount = 0;
int       batchLen   = 0;

// ------------------------------------------------------------
// BLE service / characteristic
// ------------------------------------------------------------
BLEService        imuService("A1B2C3D4-E5F6-7890-ABCD-EF1234567890");
BLECharacteristic imuChar(
    "B2C3D4E5-F6A7-8901-BCDE-F12345678901",
    BLERead | BLENotify,
    512
);

// ------------------------------------------------------------
// DFT helper
// ------------------------------------------------------------
float dft_power(float* signal, int N, int bin) {
    float re = 0, im = 0;
    for (int n = 0; n < N; n++) {
        float angle = 2.0f * 3.14159265f * bin * n / N;
        re += signal[n] * cos(angle);
        im -= signal[n] * sin(angle);
    }
    return (re * re + im * im) / N;
}

// ============================================================
// Tremor feature extraction
// ============================================================
TremorFeatures extract_tremor_features() {
    TremorFeatures f;

    float mag[WINDOW_SIZE];
    for (int i = 0; i < WINDOW_SIZE; i++) {
        float m = sqrt(buf_x[i]*buf_x[i] + buf_y[i]*buf_y[i] + buf_z[i]*buf_z[i]);
        mag[i] = m - 9.81f;
    }

    float sum_sq = 0;
    for (int i = 0; i < WINDOW_SIZE; i++) sum_sq += mag[i] * mag[i];
    f.rms = sqrt(sum_sq / WINDOW_SIZE);

    float power[26];
    float max_power = 0;
    f.dom_freq = 0;
    for (int freq = 1; freq <= 25; freq++) {
        power[freq] = dft_power(mag, WINDOW_SIZE, freq);
        if (power[freq] > max_power) {
            max_power  = power[freq];
            f.dom_freq = (float)freq;
        }
    }

    float band_power = power[4] + power[5] + power[6];
    f.log_power = log10(band_power + 1e-10f);

    return f;
}

// ============================================================
// Normalisation + ML (tremor model)
// ============================================================
void normalise(TremorFeatures& f, float out[3]) {
    float raw[3] = { f.log_power, f.rms, f.dom_freq };
    for (int i = 0; i < 3; i++) {
        out[i] = (raw[i] - FEATURE_MEAN[i]) / FEATURE_STD[i];
    }
}

float relu(float x)    { return x > 0.0f ? x : 0.0f; }
float sigmoid(float x) { return 1.0f / (1.0f + exp(-x)); }

float run_tremor_model(float input[3]) {
    float l1[8];
    for (int j = 0; j < 8; j++) {
        float sum = layer1_bias[j];
        for (int i = 0; i < 3; i++) sum += input[i] * layer1_weights[i][j];
        l1[j] = relu(sum);
    }
    float l2[4];
    for (int j = 0; j < 4; j++) {
        float sum = layer2_bias[j];
        for (int i = 0; i < 8; i++) sum += l1[i] * layer2_weights[i][j];
        l2[j] = relu(sum);
    }
    float sum = layer3_bias[0];
    for (int i = 0; i < 4; i++) sum += l2[i] * layer3_weights[i][0];
    return sigmoid(sum);
}

// ============================================================
// Setup
// ============================================================
void setup() {
    Serial.begin(115200);
    // No Serial wait — board runs fully headless from power-on

    // --- BLE first so device is discoverable immediately ---
    Bluefruit.begin();
    Bluefruit.setName("PD-Monitor");
    Bluefruit.setTxPower(4);

    imuService.begin();

    imuChar.setProperties(CHR_PROPS_READ | CHR_PROPS_NOTIFY);
    imuChar.setPermission(SECMODE_OPEN, SECMODE_NO_ACCESS);
    imuChar.setMaxLen(512);
    imuChar.begin();

    Bluefruit.Advertising.addFlags(BLE_GAP_ADV_FLAGS_LE_ONLY_GENERAL_DISC_MODE);
    Bluefruit.Advertising.addTxPower();
    Bluefruit.Advertising.addService(imuService);
    Bluefruit.ScanResponse.addName();
    Bluefruit.Advertising.restartOnDisconnect(true);
    Bluefruit.Advertising.start(0);

    // --- IMU second ---
    if (myIMU.begin() != 0) {
        Serial.println("FATAL: IMU init failed");
        while (1) delay(1000);
    }

    lastSampleTime = millis();
}

// ============================================================
// Loop
// ============================================================
void loop() {
    unsigned long currentTime = millis();

    if (currentTime - lastSampleTime >= (unsigned long)SAMPLE_INTERVAL_MS) {
        lastSampleTime = currentTime;

        // Read accelerometer (raw m/s², gravity included)
        float ax = myIMU.readFloatAccelX() * 9.81f;
        float ay = myIMU.readFloatAccelY() * 9.81f;
        float az = myIMU.readFloatAccelZ() * 9.81f;

        // Read gyroscope (deg/s)
        float gx = myIMU.readFloatGyroX();
        float gy = myIMU.readFloatGyroY();
        float gz = myIMU.readFloatGyroZ();

        // Store in ML buffers
        buf_x[buf_index] = ax;
        buf_y[buf_index] = ay;
        buf_z[buf_index] = az;

        // Build one CSV line:
        // ax_rms,log_power,dom_freq,p_tremor,severity,accX,accY,accZ,gyrX,gyrY,gyrZ
        int written = snprintf(
            bleBatch + batchLen,
            sizeof(bleBatch) - batchLen,
            "%.4f,%.4f,%d,%.4f,%s,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f\n",
            latest_rms,
            latest_log_power,
            latest_dom_freq,
            latest_p_tremor,
            latest_severity,
            ax, ay, az, gx, gy, gz
        );
        if (written > 0) batchLen += written;
        batchCount++;

        // Send batch every 10 samples (200ms)
        if (batchCount >= BLE_BATCH_SIZE) {
            if (Bluefruit.connected() && imuChar.notifyEnabled()) {
                imuChar.notify((uint8_t*)bleBatch, batchLen);
            }
            batchLen   = 0;
            batchCount = 0;
            memset(bleBatch, 0, sizeof(bleBatch));
        }

        // Advance circular index
        buf_index++;
        if (buf_index >= WINDOW_SIZE) {
            buf_index = 0;
            buf_full  = true;
        }

        // Run tremor classifier every full window (1 second)
        if (buf_full) {
            buf_full = false;

            TremorFeatures tf = extract_tremor_features();
            float normed[3];
            normalise(tf, normed);
            float tremorProb = run_tremor_model(normed);

            bool tremorDetected = (tremorProb > 0.5f)
                                && (tf.dom_freq >= 4.0f)
                                && (tf.dom_freq <= 6.0f);

            const char* tremorSeverity = "NONE";
            if (tremorDetected) {
               if      (tf.rms < 0.50f) tremorSeverity = "MILD";
               else if (tf.rms < 1.50f) tremorSeverity = "MODERATE";
               else if (tf.rms < 2.50f) tremorSeverity = "SEVERE";
               else                     tremorSeverity = "VERY_SEVERE";
            }

            // Update latest tremor values (used in next batch of CSV lines)
            latest_rms       = tf.rms;
            latest_log_power = tf.log_power;
            latest_dom_freq  = (int)tf.dom_freq;
            latest_p_tremor  = tremorProb;
            latest_severity  = tremorSeverity;

            // Serial debug
            Serial.println("===========================================");
            Serial.print  ("    rms=");      Serial.println(tf.rms, 4);
            Serial.print  ("    log_pwr=");  Serial.println(tf.log_power, 4);
            Serial.print  ("    dom_freq="); Serial.print(tf.dom_freq, 0); Serial.println(" Hz");
            Serial.print  ("    P(tremor)=");Serial.println(tremorProb, 4);
            Serial.print  ("    severity="); Serial.println(tremorSeverity);
            Serial.println("===========================================");
        }
    }
}
