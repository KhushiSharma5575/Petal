package com.petal.petal

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.speech.tts.TextToSpeech
import io.flutter.plugin.common.EventChannel
import java.util.Locale

/**
 * Petal's sensors, used only while the user runs a session (never in the
 * background), and the phone's own offline text-to-speech. Nothing leaves
 * the phone.
 *
 * - Steps (EventChannel "petal/steps"): the phone's hardware step counter.
 *   It counts all the time on every phone anyway; Petal only listens while
 *   a workout session is open and works out the difference.
 * - Face down (EventChannel "petal/facedown"): true while the phone lies
 *   screen-down, for the study focus timer. Off as soon as the timer stops.
 */
class StepsStream(context: Context) : EventChannel.StreamHandler, SensorEventListener {
    private val sensors = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager
    private val counter: Sensor? = sensors.getDefaultSensor(Sensor.TYPE_STEP_COUNTER)
    private var sink: EventChannel.EventSink? = null

    val available get() = counter != null

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        sink = events
        if (counter == null) {
            events?.error("no_sensor", "This phone has no step counter", null)
            return
        }
        sensors.registerListener(this, counter, SensorManager.SENSOR_DELAY_UI)
    }

    override fun onCancel(arguments: Any?) {
        sensors.unregisterListener(this)
        sink = null
    }

    override fun onSensorChanged(event: SensorEvent) {
        // Total steps since the phone last restarted.
        sink?.success(event.values[0].toLong())
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
}

class FaceDownStream(context: Context) : EventChannel.StreamHandler, SensorEventListener {
    private val sensors = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager
    private val gravity: Sensor? = sensors.getDefaultSensor(Sensor.TYPE_GRAVITY)
        ?: sensors.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
    private var sink: EventChannel.EventSink? = null
    private var last: Boolean? = null

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        sink = events
        last = null
        if (gravity == null) {
            events?.error("no_sensor", "This phone has no motion sensor", null)
            return
        }
        sensors.registerListener(this, gravity, SensorManager.SENSOR_DELAY_NORMAL)
    }

    override fun onCancel(arguments: Any?) {
        sensors.unregisterListener(this)
        sink = null
    }

    override fun onSensorChanged(event: SensorEvent) {
        // Lying screen-down, gravity pulls along -z (about -9.8).
        val down = event.values[2] < -7.5f
        if (down != last) {
            last = down
            sink?.success(down)
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
}

/** The phone's built-in voice (works offline with its installed voices). */
class PetalSpeaker(private val context: Context) {
    private var tts: TextToSpeech? = null
    private var ready = false
    private var queued: String? = null

    fun speak(text: String) {
        val engine = tts
        if (engine == null) {
            queued = text
            tts = TextToSpeech(context) { status ->
                ready = status == TextToSpeech.SUCCESS
                if (ready) {
                    val t = tts ?: return@TextToSpeech
                    // Indian English if installed, else the phone's default.
                    val india = Locale("en", "IN")
                    if (t.isLanguageAvailable(india) >= TextToSpeech.LANG_AVAILABLE) {
                        t.language = india
                    }
                    t.setSpeechRate(1.0f)
                    queued?.let { say(it) }
                    queued = null
                }
            }
        } else if (ready) {
            say(text)
        } else {
            queued = text
        }
    }

    private fun say(text: String) {
        tts?.speak(text, TextToSpeech.QUEUE_FLUSH, null, "petal")
    }

    fun stop() {
        tts?.stop()
    }

    fun release() {
        tts?.shutdown()
        tts = null
        ready = false
    }
}
