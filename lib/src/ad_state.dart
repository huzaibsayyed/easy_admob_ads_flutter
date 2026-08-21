/// Lifecycle states reported by every ad controller/widget in this package.
enum AdState {
  initial, // Initial state before any action
  loading, // Ad is loading
  loaded, // Ad loaded successfully and ready to show
  error, // Error occurred during loading/showing
  closed, // Ad was closed by the user
  disabled, // Ad was disabled because ads are turned off globally
}
