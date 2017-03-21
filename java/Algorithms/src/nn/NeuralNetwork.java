package nn;

import java.text.DecimalFormat;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Locale;

public class NeuralNetwork {
	static {
		Locale.setDefault(Locale.ENGLISH);
	}

	// final boolean isTrained = false;
	final DecimalFormat df;
	final ArrayList<Neuron> inputLayer = new ArrayList<Neuron>();
	final ArrayList<Neuron> hiddenLayer = new ArrayList<Neuron>();
	final ArrayList<Neuron> outputLayer = new ArrayList<Neuron>();
	final Neuron bias = new Neuron();
	final int[] layers;
	final int randomWeightMultiplier = 1;

	final double epsilon = 0.00000000001;

	final double learningRate = 0.9f;
	final double momentum = 0.1f;

	// Inputs for xor problem
	final double inputs[][] = { { 1, 1 }, { 1, 0 }, { 0, 1 }, { 0, 0 }, { 0.5, 0.5 } };

	// Corresponding outputs, xor training data
	final double expectedOutputs[][] = { { 1 }, { 0.5 }, { 0.5 }, { 0 }, { 0.5 } };
	// dummy init
	double resultOutputs[][] = Arrays.copyOf(expectedOutputs, expectedOutputs.length);
	double output[];

	// for weight update all
	// final HashMap<String, Double> weightUpdate = new HashMap<String,
	// Double>();

	public static void main(String[] args) {
		NeuralNetwork nn = new NeuralNetwork(2, 2, 1);
		int maxRuns = 50000;
		double minErrorCondition = 0.001;
		nn.run(maxRuns, minErrorCondition);
	}

	public NeuralNetwork(int input, int hidden, int output) {
		this.layers = new int[] { input, hidden, output };
		df = new DecimalFormat("#.0#");

		/**
		 * Create all neurons and connections Connections are created in the
		 * neuron class
		 */
		for (int i = 0; i < layers.length; i++) {
			// Initialize input layer
			if (i == 0) {
				for (int j = 0; j < layers[i]; j++) {
					Neuron neuron = new Neuron();
					inputLayer.add(neuron);
				}
			}
			// Initialize hidden layer
			else if (i == 1) {
				for (int j = 0; j < layers[i]; j++) {
					Neuron neuron = new Neuron();
					neuron.addInConnections(inputLayer);
					neuron.addBiasConnection(bias);
					hiddenLayer.add(neuron);
				}
			}
			// Initialize output layer
			else if (i == 2) {
				for (int j = 0; j < layers[i]; j++) {
					Neuron neuron = new Neuron();
					neuron.addInConnections(hiddenLayer);
					neuron.addBiasConnection(bias);
					outputLayer.add(neuron);
				}
			} else {
				System.out.println("!Error NeuralNetwork init");
			}
		}

		// reset id counters
		Neuron.counter = 0;
		Connection.counter = 0;

		// if (isTrained) {
		// trainedWeights();
		// updateAllWeights();
		// }
	}

	void run(int maxSteps, double minError) {
		int epochCount;
		// Train neural network until minError reached or maxSteps exceeded
		double error = 1;
		for (epochCount = 0; epochCount < maxSteps && error > minError; epochCount++) {
			error = 0;
			// Go through each example and activate and backpropagate
			for (int exampleNumber = 0; exampleNumber < inputs.length; exampleNumber++) {
				setInput(inputs[exampleNumber]);

				activate();

				output = getOutput();
				resultOutputs[exampleNumber] = output;

				// Calculate the sum of squared errors
				for (int j = 0; j < expectedOutputs[exampleNumber].length; j++) {
					double err = Math.pow(output[j] - expectedOutputs[exampleNumber][j], 2);
					error += err;
				}

				applyBackpropagation(expectedOutputs[exampleNumber]);
			}
		}

		printResult();

		System.out.println("Sum of squared errors = " + error);
		System.out.println("##### EPOCH " + epochCount + "\n");
		if (epochCount == maxSteps) {
			System.out.println("!Error training try again");
		} else {
			printAllWeights();
			printWeightUpdate();
		}
	}

	/**
	 * 
	 * @param inputs
	 *            There is equally many neurons in the input layer as there are
	 *            in input variables
	 */
	public void setInput(double inputs[]) {
		for (int i = 0; i < inputLayer.size(); i++) {
			inputLayer.get(i).setOutput(inputs[i]);
		}
	}

	public double[] getOutput() {
		double[] outputs = new double[outputLayer.size()];
		for (int i = 0; i < outputLayer.size(); i++)
			outputs[i] = outputLayer.get(i).getOutput();
		return outputs;
	}

	/**
	 * Calculate the output of the neural network based on the input The forward
	 * operation
	 */
	public void activate() {
		for (Neuron n : hiddenLayer)
			n.calculateOutput();
		for (Neuron n : outputLayer)
			n.calculateOutput();
	}

	/**
	 * all output propagate back
	 * 
	 * @param expectedOutput
	 *            first calculate the partial derivative of the error with
	 *            respect to each of the weight leading into the output neurons
	 *            bias is also updated here
	 */
	public void applyBackpropagation(double expectedOutput[]) {

		int outputNumber = 0;
		// error check, normalize value ]0;1[
		for (outputNumber = 0; outputNumber < expectedOutput.length; outputNumber++) {
			double d = expectedOutput[outputNumber];
			if (d < 0 || d > 1) {
				if (d < 0)
					expectedOutput[outputNumber] = 0 + epsilon;
				else
					expectedOutput[outputNumber] = 1 - epsilon;
			}
		}

		// Reset ouptutNumber
		outputNumber = 0;
		// Update weights for the output layer
		for (Neuron n : outputLayer) {
			ArrayList<Connection> connections = n.getAllInConnections();
			double outputNeuronOutput = n.getOutput();
			double desiredOutput = expectedOutput[outputNumber];
			double outputPartialDerivative = -outputNeuronOutput * (1 - outputNeuronOutput)
					* (desiredOutput - outputNeuronOutput);
			for (Connection con : connections) {
				double fromOutput = con.fromNeuron.getOutput();
				double partialDerivative = outputPartialDerivative * fromOutput;
				double deltaWeight = -learningRate * partialDerivative;
				double newWeight = con.getWeight() + deltaWeight;
				con.setDeltaWeight(deltaWeight);
				con.setWeight(newWeight + momentum * con.getPrevDeltaWeight());
			}
			outputNumber++;
		}

		// Update weights for the hidden layer
		for (Neuron n : hiddenLayer) {
			ArrayList<Connection> connections = n.getAllInConnections();
			for (Connection con : connections) {
				double hiddenOutput = n.getOutput();
				double fromOutput = con.fromNeuron.getOutput();
				double sumWeightCorrection = 0;
				int j = 0;
				for (Neuron outputNeuroun : outputLayer) {
					double outputNeuronWeight = outputNeuroun.getConnection(n.id).getWeight();
					double desiredOutput = (double) expectedOutput[j];
					double outputNeuronOutput = outputNeuroun.getOutput();
					j++;
					sumWeightCorrection = sumWeightCorrection + (-(desiredOutput - outputNeuronOutput)
							* outputNeuronOutput * (1 - outputNeuronOutput) * outputNeuronWeight);
				}

				double partialDerivative = hiddenOutput * (1 - hiddenOutput) * fromOutput * sumWeightCorrection;
				double deltaWeight = -learningRate * partialDerivative;
				double newWeight = con.getWeight() + deltaWeight;
				con.setDeltaWeight(deltaWeight);
				con.setWeight(newWeight + momentum * con.getPrevDeltaWeight());
			}
		}
	}

	void printResult() {
		System.out.println("NN example with xor training");
		for (int p = 0; p < inputs.length; p++) {
			System.out.print("INPUTS: ");
			for (int x = 0; x < layers[0]; x++) {
				System.out.print(inputs[p][x] + " ");
			}

			System.out.print("EXPECTED: ");
			for (int x = 0; x < layers[2]; x++) {
				System.out.print(expectedOutputs[p][x] + " ");
			}

			System.out.print("ACTUAL: ");
			for (int x = 0; x < layers[2]; x++) {
				System.out.print(resultOutputs[p][x] + " ");
			}
			System.out.println();
		}
		System.out.println();
	}

	String weightKey(int neuronId, int conId) {
		return "N" + neuronId + "_C" + conId;
	}

	/**
	 * Take from hash table and put into all weights
	 */
	// public void updateAllWeights() {
	// // update weights for the output layer
	// for (Neuron n : outputLayer) {
	// ArrayList<Connection> connections = n.getAllInConnections();
	// for (Connection con : connections) {
	// String key = weightKey(n.id, con.id);
	// double newWeight = weightUpdate.get(key);
	// con.setWeight(newWeight);
	// }
	// }
	// // update weights for the hidden layer
	// for (Neuron n : hiddenLayer) {
	// ArrayList<Connection> connections = n.getAllInConnections();
	// for (Connection con : connections) {
	// String key = weightKey(n.id, con.id);
	// double newWeight = weightUpdate.get(key);
	// con.setWeight(newWeight);
	// }
	// }
	// }

	// trained data
	// void trainedWeights() {
	// weightUpdate.clear();
	//
	// weightUpdate.put(weightKey(3, 0), 1.03);
	// weightUpdate.put(weightKey(3, 1), 1.13);
	// weightUpdate.put(weightKey(3, 2), -.97);
	// weightUpdate.put(weightKey(4, 3), 7.24);
	// weightUpdate.put(weightKey(4, 4), -3.71);
	// weightUpdate.put(weightKey(4, 5), -.51);
	// weightUpdate.put(weightKey(5, 6), -3.28);
	// weightUpdate.put(weightKey(5, 7), 7.29);
	// weightUpdate.put(weightKey(5, 8), -.05);
	// weightUpdate.put(weightKey(6, 9), 5.86);
	// weightUpdate.put(weightKey(6, 10), 6.03);
	// weightUpdate.put(weightKey(6, 11), .71);
	// weightUpdate.put(weightKey(7, 12), 2.19);
	// weightUpdate.put(weightKey(7, 13), -8.82);
	// weightUpdate.put(weightKey(7, 14), -8.84);
	// weightUpdate.put(weightKey(7, 15), 11.81);
	// weightUpdate.put(weightKey(7, 16), .44);
	// }

	public void printWeightUpdate() {
		System.out.println("printWeightUpdate, put this i trainedWeights() and set isTrained to true");
		// weights for the hidden layer
		for (Neuron n : hiddenLayer) {
			ArrayList<Connection> connections = n.getAllInConnections();
			for (Connection con : connections) {
				String w = df.format(con.getWeight());
				System.out.println("weightUpdate.put(weightKey(" + n.id + ", " + con.id + "), " + w + ");");
			}
		}
		// weights for the output layer
		for (Neuron n : outputLayer) {
			ArrayList<Connection> connections = n.getAllInConnections();
			for (Connection con : connections) {
				String w = df.format(con.getWeight());
				System.out.println("weightUpdate.put(weightKey(" + n.id + ", " + con.id + "), " + w + ");");
			}
		}
		System.out.println();
	}

	public void printAllWeights() {
		System.out.println("printAllWeights");
		// weights for the hidden layer
		for (Neuron n : hiddenLayer) {
			ArrayList<Connection> connections = n.getAllInConnections();
			for (Connection con : connections) {
				double w = con.getWeight();
				System.out.println("n=" + n.id + " c=" + con.id + " w=" + w);
			}
		}
		// weights for the output layer
		for (Neuron n : outputLayer) {
			ArrayList<Connection> connections = n.getAllInConnections();
			for (Connection con : connections) {
				double w = con.getWeight();
				System.out.println("n=" + n.id + " c=" + con.id + " w=" + w);
			}
		}
		System.out.println();
	}
}