package ann;

import java.util.HashMap;
import java.util.Map;

import logger.Logger;

public class HiddenNeuron extends AbstractNeuron {

    public HiddenNeuron(String name) {
        super(name);
    }

    private Logger logger = new Logger();

    private double globalCorrectionDelta;

    public Map<INeuron, Double> inputs = new HashMap<>();

    public double activate() {
        output = getWeightedInput();
        // Put the input sum through the decided activation function
        output = activationFunction.activate(output);

        return output;
    }

    protected double getWeightedInput() {
        double result = 0;
        // Sum all incoming neurons outputs multiplied by the
        // connection weight
        for (INeuron n : inputs.keySet()) {
            result += inputs.get(n) * n.getOutput();
        }

        return result;
    }

    /*
     * Get the global correction delta for the specific neuron
     */
    public void calculateCorrectionDelta(double target) {
        double error = target - output;
        logger.log("Error: " + error);
        this.globalCorrectionDelta = activationFunction.activate(getWeightedInput()) * error;
        logger.log(name + ": Delta output sum: " + globalCorrectionDelta);
    }

    public void adjustWeights() {
        logger.log("\nAdjusting weights for neuron " + name + ": ");
        logger.log(name + ": Global correction delta is " + globalCorrectionDelta);
        // Use the global correction delta, to calculate the specific correction
        // delta for each weight
        for (INeuron n : inputs.keySet()) {
            double weightCorrectionDelta = n.getOutput() * globalCorrectionDelta;
            logger.log("\n" + name + ": Calculating weight correction delta for weight " + inputs.get(n) + ", with "
                    + n.getName() + "'s output " + n.getOutput() + "*" + globalCorrectionDelta + " = "
                    + weightCorrectionDelta);
            double newWeight = inputs.get(n) + weightCorrectionDelta;
            logger.log(name + ": Old weight " + inputs.get(n) + ", new weight " + newWeight);
            inputs.put(n, newWeight);
            double correctionDelta = globalCorrectionDelta * inputs.get(n);
            n.adjustWeights(correctionDelta);
        }
    }

    public void adjustWeights(double correctionDelta) {
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

        result += "output: " + output;
        return result;
    }

}
