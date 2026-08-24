import { StatusBar } from 'expo-status-bar';
import { Pressable, StyleSheet, Text, View } from 'react-native';

export default function App() {
  return (
    <View style={styles.container}>
      <Text style={styles.title}>Soundcheck</Text>
      <Pressable accessibilityRole="button" style={styles.button}>
        <Text style={styles.buttonLabel}>Start</Text>
      </Pressable>
      <StatusBar style="auto" />
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#fff',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 24,
  },
  title: {
    fontSize: 32,
    fontWeight: 'bold',
  },
  button: {
    backgroundColor: '#1e90ff',
    paddingVertical: 12,
    paddingHorizontal: 32,
    borderRadius: 8,
  },
  buttonLabel: {
    color: '#fff',
    fontSize: 18,
    fontWeight: '600',
  },
});
