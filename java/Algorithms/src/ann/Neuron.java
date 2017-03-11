package ann;

import java.util.HashMap;
import java.util.Map;
import java.util.UUID;

import util.Util;

public class Neuron {

	public Neuron(double input) {
		this.cachedInput = input;
		this.cachedOutput = input;
		this.name = UUID.randomUUID().toString();
	}

	public Neuron(double input, String name) {
		this(input);
		this.name = name;
	}

	public String name = "";
	public double bias;
	public double cachedOutput;
	public double cachedInput;

	private double globalCorrectionDelta;

	public Map<Neuron, Double> weights = new HashMap<>();

	public double activate() {
		cachedInput = getInputsSum();
		// Put the input sum through the decided activation function
		cachedOutput = Util.sigmoid(cachedInput);

		return cachedOutput;
	}

	private double getInputsSum() {
		double result = 0;
		// Sum all incoming neurons outputs multiplied by the
		// connection weight
		for (Neuron n : weights.keySet()) {
			result += weights.get(n) * n.cachedOutput;
		}

		return result;
	}

	/*
	 * Get the global correction delta for the specific neuron
	 */
	public void calculateCorrectionDelta(double target) {
		double error = target - cachedOutput;
		System.out.println("Error: " + error);
		this.globalCorrectionDelta = Util.sigmoidDerivative(getInputsSum()) * error;
		System.out.println(name + ": Delta output sum: " + globalCorrectionDelta);
	}

	public void adjustWeights() {
		System.out.println("\nAdjusting weights for neuron " + name + ": ");
		System.out.println(name + ": Global correction delta is " + globalCorrectionDelta);
		// Use the global correction delta, to calculate the specific correction
		// delta for each weight
		for (Neuron n : weights.keySet()) {
			double weightCorrectionDelta = n.cachedOutput * globalCorrectionDelta;
			System.out.println("\n" + name + ": Calculating weight correction delta for weight " + weights.get(n)
					+ ", with " + n.name + "'s output " + n.cachedOutput + "*" + globalCorrectionDelta + " = "
					+ weightCorrectionDelta);
			double newWeight = weights.get(n) + weightCorrectionDelta;
			System.out.println(name + ": Old weight " + weights.get(n) + ", new weight " + newWeight);
			weights.put(n, newWeight);
			double correctionDelta = globalCorrectionDelta*weights.get(n)*Util.sigmoidDerivative(n.cachedInput);
			n.adjustWeights(correctionDelta);
		}
	}

	public void adjustWeights(double correctionDelta) {
		System.out.println("\nAdjusting weights for neuron " + name + ": ");
		// Use the global correction delta, to calculate the specific correction
		// delta for each weight
		for (Neuron n : weights.keySet()) {
			double weightCorrectionDelta = n.cachedOutput * correctionDelta;
			System.out.println(
					name + ": Adjusting weight " + weights.get(n) + ", with " + n.cachedOutput + "*" + correctionDelta);
			double newWeight = weights.get(n) + weightCorrectionDelta;
			System.out.println(name + ": Old weight " + weights.get(n) + ", new weight " + newWeight);
			weights.put(n, newWeight);
		}
	}

	@Override
	public String toString() {
		String result = name + ": ";

		if (!weights.isEmpty()) {
			result += "Weights: ";
			for (Neuron n : weights.keySet()) {
				result += weights.get(n) + ", ";
			}
		}

		result += "output: " + cachedOutput;
		return result;
	}

}
