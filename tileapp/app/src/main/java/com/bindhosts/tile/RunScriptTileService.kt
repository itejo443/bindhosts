package com.bindhosts.tile

import android.content.Context
import android.content.SharedPreferences
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import java.io.BufferedReader
import java.io.InputStreamReader
import java.io.IOException

class RunScriptTileService : TileService() {

    // SharedPreferences for storing the tile state
    private val prefsFileName = "tile_prefs"
    private val tileStateKey = "tile_state"

    override fun onClick() {
        // Toggle the tile state and run the appropriate script
        toggleTileState()
    }

    override fun onTileAdded() {
        // Load saved state when the tile is added to Quick Settings
        val savedState = loadTileState()
        qsTile.state = savedState
        qsTile.updateTile()
    }

    override fun onStartListening() {
        // Run the bindhosts.sh script and check the status when the tile is shown
        runBindHostsScriptAndCheckStatus()
    }

    private fun toggleTileState() {
        if (qsTile.state == Tile.STATE_INACTIVE) {
            // If tile is inactive, run action.sh
            runScriptAndCheckStatus()
        } else {
            // If tile is active, execute reset
            resetBindHosts()
        }
    }

    private fun runScriptAndCheckStatus() {
        try {
            // Execute action.sh script
            executeScript("sh /data/adb/modules/bindhosts/bindhosts.sh --action")
            // After action.sh completes, check the bindhosts status
            runBindHostsScriptAndCheckStatus()
        } catch (e: IOException) {
            handleError(e)
        } catch (e: InterruptedException) {
            handleError(e)
        }
    }

    private fun runBindHostsScriptAndCheckStatus() {
        try {
            // Execute the bindhosts.sh script as root
            val process = ProcessBuilder("su", "-c", "sh /data/adb/modules/bindhosts/bindhosts.sh").start()
            val reader = BufferedReader(InputStreamReader(process.inputStream))
            val lines = mutableListOf<String>()

            // Read script output line by line
            var line: String?
            while (reader.readLine().also { line = it } != null) {
                lines.add(line ?: "")
            }

            process.waitFor() // Wait for the script to finish

            // Log the output for debugging
            android.util.Log.d("BindHostsOutput", "Script Output: $lines")

            // Check the 5th line for the active status
            if (lines.size >= 5 && lines[4].startsWith("[%] status: active")) {
                qsTile.state = Tile.STATE_ACTIVE
            } else {
                qsTile.state = Tile.STATE_INACTIVE
            }
            // Update the tile and save the state
            qsTile.updateTile()
            saveTileState(qsTile.state)

        } catch (e: IOException) {
            handleError(e)
        } catch (e: InterruptedException) {
            handleError(e)
        }
    }

    private fun executeScript(script: String) {
        // Execute a generic script as root
        val process = ProcessBuilder("su", "-c", script).start()
        process.waitFor()  // Wait for the script to finish
    }

    private fun resetBindHosts() {
        try {
            // Execute the reset script to turn the tile off
            executeScript("cd /data/adb/modules/bindhosts && sh bindhosts.sh --force-reset")
            qsTile.state = Tile.STATE_INACTIVE
            qsTile.updateTile()
            saveTileState(qsTile.state)
        } catch (e: IOException) {
            handleError(e)
        }
    }

    private fun handleError(e: Exception) {
        // Handle any error during script execution or IO issues
        android.util.Log.e("BindHosts", "Error during script execution", e)
        qsTile.state = Tile.STATE_INACTIVE
        qsTile.updateTile()
    }

    private fun saveTileState(state: Int) {
        // Save the tile state to SharedPreferences
        val sharedPreferences: SharedPreferences = getSharedPreferences(prefsFileName, Context.MODE_PRIVATE)
        val editor = sharedPreferences.edit()
        editor.putInt(tileStateKey, state)
        editor.apply()  // Apply changes asynchronously
    }

    private fun loadTileState(): Int {
        // Load the saved state from SharedPreferences
        val sharedPreferences: SharedPreferences = getSharedPreferences(prefsFileName, Context.MODE_PRIVATE)
        return sharedPreferences.getInt(tileStateKey, Tile.STATE_INACTIVE)
    }
}













