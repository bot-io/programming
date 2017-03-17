package ann;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

import logger.Logger;

public class HiddenNeuron extends AbstractNeuron {

    public HiddenNeuron(String name) {
        super(name);
    }

    private Logger logger = new Logger();
    protected double weightedInput;
	protected double globalCorrectionDelta;
	
	/*
     * Get the global correction delta for the specific neuron
     */
    public double getGlobalCorrectionDelta() {
		return globalCorrectionDelta;
	}
	
	public void setGlobalCorrectionDelta(double value){
		globalCorrectionDelta = value;
	}
	

    public Map<INeuron, Double> inputs = new HashMap<>();

    public double activate() {
        output = getWeightedInput();
        // Put the input sum through the decided activation function
        output = activationFunction.activate(output);

        return output;
    }

    public void addInput(INeuron n, double weight) {
        inputs.put(n, weight);
    }

    public void addInput(INeuron n) {
        this.addInput(n, Math.random());
    }

    public void addInputs(List<INeuron> ns) {
        for (INeuron n : ns) {
            this.addInput(n);
        }
    }

    protected double getWeightedInput() {
        weightedInput = 0;
        // Sum all incoming neurons outputs multiplied by the
        // connection weight
        for (INeuron n : inputs.keySet()) {
            weightedInput += inputs.get(n) * n.getOutput();
        }

        return weightedInput;
    }

    public void adjustWeights() {
		double correctionDelta = getGlobalCorrectionDelta();
        correctionDelta = correctionDelta * activationFunction.derivative(getWeightedInput());
        logger.log("\nAdjusting weights for neuron " + name + ": ");
        // Use the global correction delta, to calculate the specific correction
        // delta for each weight
        for (INeuron n : inputs.keySet()) {
            double weightCorrectionDelta = n.getOutput() * correctionDelta;
            logger.log(name + ": Adjusting weight " + inputs.get(n) + ", with " + n.getOutput() + "*" + correctionDelta);
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
            for (INeuron n : inputs.keySet()) {
                result += inputs.get(n) + ", ";
            }
        }

        result += "output: " + getOutput();
        return result;
    }

}
