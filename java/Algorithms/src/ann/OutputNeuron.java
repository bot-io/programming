package ann;

import java.util.HashMap;
import java.util.Map;
import java.util.UUID;

import ann.activation.IActivationFunction;
import ann.activation.SigmoidActivationFunction;
import logger.Logger;
import util.Util;

public class OutputNeuron extends AbstractNeuron{

	private Logger logger = new Logger();

	public OutputNeuron(double input) {
		this.inputSum = input;
		this.output = input;
		this.name = UUID.randomUUID().toString();
	}

	public OutputNeuron(double input, String name) {
		this(input);
		this.name = name;
	}

	
	private double globalCorrectionDelta;

	public Map<OutputNeuron, Double> inputs = new HashMap<>();

	public double activate() {
		inputSum = getInputsSum();
		// Put the input sum through the decided activation function
		output = activationFunction.activate(inputSum);

		return output;
	}

	private double getInputsSum() {
		double result = 0;
		// Sum all incoming neurons outputs multiplied by the
		// connection weight
		for (OutputNeuron n : inputs.keySet()) {
			result += inputs.get(n) * n.output;
		}

		return result;
	}

	/*
	 * Get the global correction delta for the specific neuron
	 */
	public void calculateCorrectionDelta(double target) {
		double error = target - output;
		logger.log("Error: " + error);
		this.globalCorrectionDelta = Util.sigmoidDerivative(getInputsSum()) * error;
		logger.log(name + ": Delta output sum: " + globalCorrectionDelta);
	}

	public void adjustWeights() {
		logger.log("\nAdjusting weights for neuron " + name + ": ");
		logger.log(name + ": Global correction delta is " + globalCorrectionDelta);
		// Use the global correction delta, to calculate the specific correction
		// delta for each weight
		for (OutputNeuron n : inputs.keySet()) {
			double weightCorrectionDelta = n.output * globalCorrectionDelta;
			logger.log("\n" + name + ": Calculating weight correction delta for weight " + inputs.get(n) + ", with "
					+ n.name + "'s output " + n.output + "*" + globalCorrectionDelta + " = " + weightCorrectionDelta);
			double newWeight = inputs.get(n) + weightCorrectionDelta;
			logger.log(name + ": Old weight " + inputs.get(n) + ", new weight " + newWeight);
			inputs.put(n, newWeight);
			double correctionDelta = globalCorrectionDelta * inputs.get(n) * Util.sigmoidDerivative(n.inputSum);
			n.adjustWeights(correctionDelta);
		}
	}

	public void adjustWeights(double correctionDelta) {
		logger.log("\nAdjusting weights for neuron " + name + ": ");
		// Use the global correction delta, to calculate the specific correction
		// delta for each weight
		for (OutputNeuron n : inputs.keySet()) {
			double weightCorrectionDelta = n.output * correctionDelta;
			logger.log(name + ": Adjusting weight " + inputs.get(n) + ", with " + n.output + "*" + correctionDelta);
			double newWeight = inputs.get(n) + weightCorrectionDelta;
			logger.log(name + ": Old weight " + inputs.get(n) + ", new weight " + newWeight);
			inputs.put(n, newWeight);
		}
	}

	@Override
	public String toString() {
		String result = name + ": ";

		if (!inputs.isEmpty()) {
			result += "Weights: ";
			for (OutputNeuron n : inputs.keySet()) {
				result += inputs.get(n) + ", ";
			}
		}

		result += "output: " + output;
		return result;
	}

}
