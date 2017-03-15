package ann;

import logger.Logger;

public class OutputNeuron extends HiddenNeuron {

    private Logger logger = new Logger();

    public OutputNeuron(String name) {
        super(name);
    }

    protected double globalCorrectionDelta;

    double target;

    public void setTarget(double target) {
        this.target = target;
    }

    /*
     * Get the global correction delta for the specific neuron
     */
    public void calculateCorrectionDelta() {
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
            if (n instanceof HiddenNeuron) {
                double correctionDelta = globalCorrectionDelta * inputs.get(n);
                ((HiddenNeuron) n).adjustWeights(correctionDelta);
            }
        }
    }

    @Override
    public String toString() {
        return super.toString() + ", target: " + target;
    }
}
