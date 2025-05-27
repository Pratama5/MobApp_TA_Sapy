# 📱 Flutter Audio Watermarking App

This mobile application allows users to **embed** and **extract audio watermarks** using a custom server powered by **FastAPI**, **MATLAB `.exe` executables**, and **Supabase Storage & Database**.

---

## 🧠 System Architecture

```
Flutter App  <-->  FastAPI Server (.exe wrapped)  <-->  Supabase (Storage + DB)
```

### ✔️ Embedding Flow

1. **User selects**:
   - An audio file (from Supabase)
   - A watermark image
   - Method and parameters (`bit`, `subband`, `alfass`)

2. **Flutter sends** a POST request to `/embed` with audio/image URLs and config

3. **FastAPI server**:
   - Downloads the audio and image
   - Runs the `embedding_production3.exe`
   - Uploads the watermarked audio to Supabase (`media/results/`)
   - Uploads the key `.mat` file to Supabase (`media/keys/`)
   - Inserts metadata into `audio_watermarked` table

4. **Flutter shows** playback of the result and metadata like BER, SNR, etc.

---

### ✔️ Extraction Flow

1. **User selects** a watermarked audio from the dropdown

2. **Flutter sends**:
   ```json
   {
     "audio_url": ".../gitar.wav",
     "filename": "gitar.wav"
   }
   ```

3. **FastAPI server**:
   - Looks up the key `.mat` in `audio_watermarked`
   - Downloads both `.wav` and `.mat`
   - Runs `extraction_production2.exe`
   - Extracts watermark image (`_extracted_watermark.png`)
   - Uploads it to Supabase (`watermarked/images/`)
   - Inserts a row into `image_extracted` table

4. **Flutter displays** the extracted watermark and BER

---

## 🚀 Project Setup

### 🔹 Flutter

```bash
flutter pub get
flutter run
```

### 🔹 FastAPI Server

```bash
pip install -r requirements.txt
uvicorn server:app --host 0.0.0.0 --port 8000
```

Ensure `.exe` files and `temp_input`, `temp_output` folders are set.

---

## 📂 Supabase Schema

### ✅ `audio_watermarked` Table

| Column         | Type     | Description                         |
|----------------|----------|-------------------------------------|
| `filename`     | text     | Audio file name                     |
| `url`          | text     | Public URL to watermarked audio     |
| `key_url`      | text     | URL to `.mat` file                  |
| `method`       | text     | Embedding method used               |
| `bit`, `subband` | int   | Embedding parameters                |
| `alfass`       | numeric  | Scaling factor                      |
| `snr`          | numeric  | Signal-to-noise ratio               |
| `uploaded_by`  | uuid     | Supabase user ID                    |
| `uploaded_at`  | timestamp| Jakarta time of upload              |

### ✅ `image_extracted` Table

| Column         | Type     | Description                         |
|----------------|----------|-------------------------------------|
| `filename`     | text     | Extracted image name                |
| `url`          | text     | Public URL to extracted watermark   |
| `source_audio` | text     | Refers to source `.wav` used        |
| `ber`          | numeric  | Bit error rate                      |
| `uploaded_at`  | timestamp| Jakarta time of upload              |

---

## ✨ Features

- Offline `.exe` support (via MATLAB-compiled binary)
- Cloud file management with Supabase Storage
- SNR, BER, and parameter tracking per operation
- Mini audio player and extraction preview UI
